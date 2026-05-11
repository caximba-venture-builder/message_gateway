# Backlog — Production Readiness do Message Gateway

## Contexto

Backlog derivado de uma revisão completa do projeto `message_gateway` (broker WhatsApp via Evolution API + RabbitMQ + OpenAI Whisper, Rails 8.1).

Decisões de escopo já tomadas pelo time:
- **SQLite mantido** (uso restrito a `solid_cache` e `solid_queue`; primário em SQLite é aceitável dada a carga atual).

Formato: cada item é uma história ou tarefa com **Problema/Tarefa**, **Critérios de aceite** e referências a arquivos. Agrupado por prioridade.

---

## P0 — Bloqueadores reais (corrigir antes de tráfego sério)

### ✅ TASK-001 — Mover envio outgoing para job assíncrono
**Problema:** `OutgoingMessagesConsumer` chama `OutgoingMessageSenderService.call` direto no callback do Bunny, e o service faz `sleep(typing_delay)` síncrono (`app/services/outgoing_message_sender_service.rb:19`). Com `prefetch(1)`, throughput cai a quase zero.

**Tarefa:** consumer apenas valida payload e enfileira `OutgoingMessageJob` no Solid Queue; `sleep` e chamadas HTTP ficam no job.

**Aceite:**
- Consumer dá ACK em < 50ms.
- `OutgoingMessageJob` com retry (`retry_on EvolutionApiClient::ApiError`, `attempts: 3`).
- Teste novo cobre: 10 mensagens de 200 chars consumidas em < 1s no consumer.

**Arquivos:** `app/consumers/outgoing_messages_consumer.rb`, `app/services/outgoing_message_sender_service.rb`, `app/jobs/outgoing_message_job.rb` (criar se não existir).

---

### ✅ TASK-002 — Graceful shutdown do ConsumerManager
**Problema:** `consumer_manager.rb:21,27` usa busy-loop `sleep(1) while @running`, `@heartbeat_thread&.kill` sem `join`, e não aguarda in-flight messages → re-delivery em crash/deploy.

**Aceite:**
- SIGTERM/SIGINT param de aceitar novas deliveries imediatamente.
- Aguarda in-flight com timeout configurável (default 30s).
- `heartbeat_thread.join` antes de retornar.
- Teste de integração: enviar SIGTERM durante processamento → mensagem em curso é ACK ou NACK explícito (não re-entregue).

**Arquivos:** `app/consumers/consumer_manager.rb`, `bin/consumer`.

---

### ✅ TASK-003 — Guard clauses e error tracking no AudioTranscriptionJob
**Problema:** `app/jobs/audio_transcription_job.rb:13,23` — `Sender.find` quebra silenciosamente se sender deletado; `Message.find_by` retorna `nil` e `TokenUsage.create!` posterior viola FK sem log.

**Aceite:**
- `discard_on ActiveRecord::RecordNotFound`.
- Guard clause para `message.nil?` com log estruturado (`message_id`, `sender_id`).
- Teste: sender deletado → job descartado, sem exceção propagada.
- Teste: message deletada → job retorna cedo com warning.

**Arquivos:** `app/jobs/audio_transcription_job.rb`.

---

### ✅ TASK-004 — Timeouts explícitos em integrações externas
**Problema:** `EvolutionApiClient`, `AudioDownloader` e `OpenAI` sem timeouts explícitos → uma API lenta congestiona o pool de jobs.

**Aceite:**
- `open_timeout: 5s`, `read_timeout: 30s` em todas as chamadas HTTP.
- OpenAI Whisper com timeout de 120s (configurável via env).
- Em timeout, exceção customizada por client é levantada e capturada por `retry_on` do job.

**Arquivos:** `app/clients/evolution_api_client.rb`, `app/clients/audio_downloader.rb`, `config/initializers/openai.rb`.

---

### TASK-005 — Limite de tamanho do áudio antes do upload
**Problema:** `AudioTranscriptionService` faz upload sem checar tamanho do arquivo (risco de OOM/timeout/custo).

**Aceite:**
- Constante `MAX_AUDIO_BYTES` (ex.: 25MB, limite OpenAI).
- Arquivo acima do limite: job descartado, log estruturado, métrica `audio_oversize_total`.

**Arquivos:** `app/services/audio_transcription_service.rb`, `app/clients/audio_downloader.rb`.

---

### TASK-006 — Não persistir `apikey`/`raw_payload` sensível em ParsedMessage
**Problema:** `ParsedMessage` carrega `raw_payload` inteiro contendo `apikey` da Evolution. Se for serializado em error tracker, vaza credencial.

**Aceite:**
- `ParsedMessage` armazena só campos necessários (sem `apikey`).
- Se `raw_payload` precisar persistir, redact `apikey`/tokens.
- Teste: serializar `ParsedMessage` para JSON → não contém `apikey`.

**Arquivos:** `app/models/value_objects/parsed_message.rb`, `app/services/message_parser.rb`.

---

## P1 — Operação básica em produção

### STORY-101 — Como SRE quero logs estruturados JSON com correlation_id
Para conseguir rastrear uma mensagem do webhook ao publish na fila final.

**Aceite:**
- Lograge configurado em `config/initializers/lograge.rb` (gem já está no Gemfile).
- Output JSON, com campos: `request_id`, `correlation_id`, `message_id`, `sender_id` (mascarado), `queue`, `duration_ms`.
- Consumer gera `correlation_id` (UUID) por mensagem e propaga via `ActiveSupport::CurrentAttributes` para job/service/publisher.
- Teste: rodar `IncomingMessageJob` → log JSON contém `correlation_id`.

**Arquivos:** `config/initializers/lograge.rb` (criar), `app/consumers/application_consumer.rb`, `app/jobs/application_job.rb`, novo `CurrentRequest < ActiveSupport::CurrentAttributes`.

---

### STORY-102 — Como SRE quero error tracking com Sentry
Para ser notificado de exceções não tratadas em consumers/jobs.

**Aceite:**
- Gem `sentry-ruby` + `sentry-rails` adicionada.
- DSN via `SENTRY_DSN` env (opcional em dev).
- `Rails.error.report` chamado em `ApplicationConsumer#handle_error` e em `discard_on`/`retry_on` de jobs.
- Filtros para não enviar PII (telefone redacted, payload truncado).
- Teste: simular exceção em job → reportada com tags `job:...`, `correlation_id:...`.

**Arquivos:** `Gemfile`, `config/initializers/sentry.rb` (criar), `app/consumers/application_consumer.rb`.

---

### STORY-103 — Como operador quero health check real
Para que o orquestrador (Kamal) detecte indisponibilidade efetiva.

**Aceite:**
- `bin/health` valida: arquivo de heartbeat recente (< 30s), conexão RabbitMQ (`Bunny.connection.open?`), DB (`ActiveRecord::Base.connection.active?`).
- Endpoint `/health/detailed` no Rails retorna JSON com status de cada dependência.
- Dockerfile HEALTHCHECK aponta para `bin/health` ou endpoint detalhado.
- Teste: parar RabbitMQ → `bin/health` exit 1.

**Arquivos:** `bin/health`, `bin/health-consumer`, `config/routes.rb`, novo `HealthController`.

---

### STORY-104 — Como operador quero saber quando a DLQ cresce
Hoje DLQ pode crescer indefinidamente sem alerta.

**Aceite:**
- Métrica/log periódico de tamanho da DLQ por fila (recurring job, intervalo 1min).
- Documentação em `README.md` ou `docs/runbooks/` com query/script para inspecionar e re-enfileirar DLQ.

**Arquivos:** `config/recurring.yml`, novo `app/jobs/dlq_size_metric_job.rb`, `docs/runbooks/dlq.md` (criar).

---

### TASK-105 — Cleanup job para `ConcatenationBuffer` expirados
**Problema:** Scope `expired` definido (`concatenation_buffer.rb:16`) mas nunca chamado → buffers órfãos se acumulam.

**Aceite:**
- Recurring job (Solid Queue) executando 1x/hora apaga buffers com `expires_at <= 24h.ago`.
- Métrica de quantos foram apagados.

**Arquivos:** `config/recurring.yml`, novo `app/jobs/concatenation_buffer_cleanup_job.rb`.

---

### TASK-106 — Reuso de channel Bunny no ApplicationPublisher
**Problema:** `ApplicationPublisher#with_channel` abre/fecha channel a cada publish — anti-padrão Bunny.

**Aceite:**
- Pool de channels por thread (ou channel persistente reutilizado).
- Bench: 1000 publishes seguidos com latência média < pré-mudança.

**Arquivos:** `app/publishers/application_publisher.rb`, `lib/rabbit_mq/connection.rb`.

---

### TASK-107 — Retry e DLQ próprio para `ProcessedMessagePublisher`
**Problema:** Falha de publish é silenciosa, mensagem perdida.

**Aceite:**
- Em falha, retry exponencial (3 tentativas).
- Após exausto, persistir em tabela `failed_publishes` ou DLQ específica + alerta.

**Arquivos:** `app/publishers/processed_message_publisher.rb`, `app/publishers/application_publisher.rb`.

---

## P2 — Resiliência e qualidade

### STORY-201 — Como SRE quero circuit breaker em integrações externas
Para que a fila de jobs não congestione quando Evolution/OpenAI estão fora.

**Aceite:**
- Gem `circuitbox` (ou similar) integrada em `EvolutionApiClient` e `AudioTranscriptionService`.
- Threshold: 50% de erro em janela de 60s abre o circuito por 30s.
- Em circuit open: job re-enfileira com backoff longo, sem bater na API.

**Arquivos:** `app/clients/evolution_api_client.rb`, `app/services/audio_transcription_service.rb`.

---

### STORY-202 — Como dev quero teste E2E do fluxo de mensagem
Para detectar regressões no contrato consumer→job→publisher.

**Aceite:**
- Spec de integração que sobe RabbitMQ via docker-compose.test ou usa `bunny-mock` realista.
- Caminho feliz `conversation`: payload → consumer → job → buffer → flush → publisher.
- Caminho áudio: payload → consumer → job → Whisper (stub) → publisher.
- Caminho falha: 4 falhas consecutivas → DLQ.

**Arquivos:** `spec/integration/`, `spec/support/rabbitmq_helper.rb`.

---

### TASK-203 — Teste de concorrência para `MessageConcatenationService` + flush
**Problema:** Sem testes de dois workers concorrendo no mesmo sender.

**Aceite:**
- Spec que dispara 2 threads chamando o service simultaneamente.
- Verifica `with_lock` previne corrida; nenhum buffer com texto duplicado.

---

### TASK-204 — Métricas básicas (Prometheus ou DataDog)
**Aceite:**
- Métricas: `consumer_messages_total{queue,status}`, `job_duration_seconds{class}`, `dlq_size{queue}`, `evolution_api_errors_total`, `openai_tokens_total`.
- Endpoint `/metrics` ou push para DD.

**Arquivos:** `Gemfile` (`prometheus_exporter` ou `dogstatsd-ruby`), inicializadores.

---

### TASK-205 — `.env.example` completo
**Aceite:** todas as envs do `CLAUDE.md` listadas com defaults documentados.

---

### TASK-206 — Simplificar `SenderRegistrationService`
Trocar `find_or_create_by!` + rescue + lookup por `find_or_create_by` direto (índice único cobre a corrida).

---

## P3 — Compliance e segurança avançada

### STORY-301 — Como compliance officer quero que conteúdo de mensagem seja criptografado
**Aceite:**
- `ConcatenationBuffer.accumulated_text` com `encrypts :accumulated_text` (Active Record encryption).
- Migration de chaves via `rails db:encryption:init` documentada.
- Considerar mesma proteção em `Message` se passar a guardar conteúdo.

**Arquivos:** `app/models/concatenation_buffer.rb`, `config/credentials/`.

---

### STORY-302 — Como compliance officer quero política de retenção
**Aceite:**
- Job de purge: mensagens/buffers/audit com idade > N dias (configurável; default 90).
- Documentação em `docs/lgpd.md`.

---

### STORY-303 — Como usuário final tenho direito ao esquecimento
**Aceite:**
- Rake task ou script: `rails forget_me[phone_number]` apaga/anonimiza dados do sender em todas as tabelas.
- Log de auditoria do request.

---

### TASK-304 — Rate limit no envio outgoing por instância
**Aceite:**
- Token bucket (em Solid Cache ou Redis se houver) por `instance_name`.
- Default: 1 msg/s, configurável via env.
- Excesso: job re-enfileirado com delay.

---

### TASK-305 — Brakeman config e revisão de findings
**Aceite:** `.brakeman.yml` com ignores justificados; CI falha em qualquer warning novo.

---

## P4 — Polimento

- **TASK-401** — Mover `dotenv-rails` para grupo `:development, :test` no Gemfile (verificar).
- **TASK-402** — `RAILS_LOG_LEVEL` com default `info` em `production.rb`.
- **TASK-403** — Tunar `JOB_CONCURRENCY` em `config/queue.yml` para o hardware-alvo e documentar.
- **TASK-404** — Smoke test pós-deploy no hook do Kamal (ping `/health/detailed`).
- **TASK-405** — Runbooks em `docs/runbooks/`: `rabbitmq-down.md`, `openai-quota.md`, `dlq-grew.md`, `consumer-stuck.md`.
- **TASK-406** — Aumentar cobertura de edge cases nos parsers (`TextMessageParser`, `AudioMessageParser`, `OutgoingMessageParser`).
- **TASK-407** — Adicionar `phone_number` ao `filter_parameters` (hoje não está em `log_redaction.rb`).

---

## Resumo por prioridade

| Prioridade | Itens | Foco |
|---|---|---|
| P0 | 6 tarefas | bugs/risco imediato |
| P1 | 7 itens (4 stories + 3 tasks) | observabilidade e operação |
| P2 | 6 itens | resiliência e testes |
| P3 | 5 itens | compliance/segurança |
| P4 | 7 itens | polimento |

**Total: 31 itens.**

---

## Próximos passos sugeridos

1. Validar prioridades com o time.
2. Importar P0/P1 para o tracker (Linear/Jira/GitHub Issues).
3. Para cada P0, abrir PR com teste de regressão antes do fix.
