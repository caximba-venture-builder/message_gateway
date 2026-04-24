# Message Gateway — Plano de Implementação

## Contexto

O projeto é um message broker/gateway para WhatsApp via Evolution API. Consome mensagens de filas RabbitMQ, concatena mensagens de texto do mesmo remetente dentro de uma janela de tempo configurável, transcreve mensagens de áudio via OpenAI Whisper, e produz mensagens processadas para outra fila RabbitMQ. O projeto é greenfield — apenas `docs/IDEA.md` existe.

---

## Fase 1 — Scaffold do Rails e Configuração Base

### 1.1 Gerar o projeto Rails 8

```bash
rails new message_gateway --database=sqlite3 --skip-action-mailer --skip-action-mailbox --skip-action-text --skip-hotwire --skip-jbuilder --skip-system-test --skip-kamal --api
```

Instalar Solid Queue e Solid Cache:
```bash
bin/rails solid_queue:install
bin/rails solid_cache:install
```

### 1.2 Gemfile (adições)

```ruby
# Messaging
gem "bunny", "~> 2.23"

# Transcription
gem "ruby-openai", "~> 7.0"

# Logging
gem "lograge"

group :development, :test do
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "simplecov", require: false
  gem "webmock"
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end
```

### 1.3 `config/database.yml` — SQLite WAL com databases separados

Três databases: primary, queue, cache. Pragmas: `journal_mode: wal`, `synchronous: normal`, `busy_timeout: 5000`.

### 1.4 `.env.example`

```bash
# RabbitMQ (conecta no RabbitMQ de produção em todos os ambientes)
RABBITMQ_URL=amqp://user:password@your-rabbitmq-host:5672
RABBITMQ_QUEUES=materny-bot-ai.messages.upsert
PROCESSED_MESSAGES_QUEUE=materny-bot-ai.messages.processed
MESSAGE_CONVERSATION_CONCAT_WINDOW=15
MESSAGE_MAX_RETRY_COUNT=3
OPENAI_API_KEY=sk-...
OPENAI_TRANSCRIPTION_MODEL=whisper-1
OPENAI_TRANSCRIPTION_LANGUAGE=pt
```

---

## Fase 2 — Modelos e Migrations

### Tabelas

**senders** (id: uuid PK)
- `phone_number` string NOT NULL, unique index
- `push_name` string NOT NULL
- `os` string
- timestamps

**messages** (id: uuid PK)
- `whatsapp_message_id` string NOT NULL, index
- `message_type` string NOT NULL (`conversation` | `audioMessage`)
- `sender_id` uuid FK NOT NULL, index composto com `message_timestamp`
- `message_timestamp` integer NOT NULL
- `sender_os` string
- timestamps

**token_usages** (id: uuid PK)
- `sender_id` uuid FK NOT NULL
- `message_id` uuid FK NOT NULL
- `tokens_used` integer NOT NULL default 0
- `model_name` string
- timestamps

**concatenation_buffers** (id: uuid PK)
- `sender_id` uuid FK NOT NULL
- `instance_name` string NOT NULL
- `accumulated_text` text NOT NULL default ""
- `expires_at` datetime NOT NULL, index
- `message_count` integer NOT NULL default 0
- unique index em `[sender_id, instance_name]`
- timestamps

### Modelos AR

- `app/models/sender.rb` — has_many :messages, :token_usages, :concatenation_buffers
- `app/models/message.rb` — belongs_to :sender, validates message_type in %w[conversation audioMessage]
- `app/models/token_usage.rb` — belongs_to :sender, :message
- `app/models/concatenation_buffer.rb` — belongs_to :sender, scope :expired

---

## Fase 3 — Value Objects e Parser

**`app/models/value_objects/parsed_message.rb`** — `Data.define` com campos normalizados:
- event, instance_name, server_url, date_time
- sender_phone_number (extraído de `sender`, sem `@s.whatsapp.net`)
- whatsapp_message_id (`data.key.id`)
- push_name, message_type, message_timestamp, source_os
- message_body (texto para conversation, nil para audio)
- audio_url, audio_mimetype, audio_file_length
- raw_payload

**`app/services/message_parser.rb`** — Recebe payload Hash bruto, valida campos obrigatórios, retorna `ParsedMessage`. Raise `ParseError` se inválido.

---

## Fase 4 — RabbitMQ Layer

Distribuir em pastas dedicadas ao invés de concentrar tudo em `app/services/`:

### Conexão — `lib/rabbit_mq/`

**`lib/rabbit_mq/connection.rb`** — Singleton thread-safe com Bunny. Auto-recovery, heartbeat 30s, 10 tentativas de reconexão. Fica em `lib/` pois é infraestrutura, não lógica de negócio. Autoloaded via `config/initializers/rabbit_mq.rb` que configura os parâmetros de conexão a partir das env vars.

### Publishers — `app/publishers/`

**`app/publishers/application_publisher.rb`** — Base class com lógica comum de publicação (abrir channel, publicar com `persistent: true`, fechar channel).

**`app/publishers/processed_message_publisher.rb`** — Publica mensagens processadas no `PROCESSED_MESSAGES_QUEUE`. Herda de `ApplicationPublisher`. Formata o payload no formato exato: `{ id:, phone_number:, text:, name: }`.

**`app/publishers/dead_letter_publisher.rb`** — Publica mensagens falhadas no DLQ (`<queue>.dlq`). Envolve o payload original com metadata de erro (error, retry_count, failed_at, source_queue).

### Consumers — `app/consumers/`

**`app/consumers/application_consumer.rb`** — Base class com lógica de subscribe (`manual_ack: true`, `prefetch: 1`), retry via header `x-retry-count`, e dead letter após 3 falhas.

**`app/consumers/messages_consumer.rb`** — Consumer específico para filas `<instance>.messages.upsert`. Herda de `ApplicationConsumer`. Parseia o payload e enfileira `IncomingMessageJob`.

**`app/consumers/consumer_manager.rb`** — Gerencia múltiplos consumers, trap SIGINT/SIGTERM para graceful shutdown. Itera sobre `RABBITMQ_QUEUES` e inicia um `MessagesConsumer` para cada.

### Entry Points

**`bin/consumer`** — Entry point standalone que boota Rails e inicia `ConsumerManager`.

---

## Fase 5 — Service Objects

### Strategy Pattern

**`app/strategies/base_strategy.rb`** — Interface com `initialize(parsed_message, sender)` e `call`.

**`app/strategies/conversation_strategy.rb`** — Delega para `MessageConcatenationService`.

**`app/strategies/audio_message_strategy.rb`** — Enfileira `AudioTranscriptionJob`.

**`app/strategies/message_strategy_resolver.rb`** — Hash lookup `{ "conversation" => ConversationStrategy, "audioMessage" => AudioMessageStrategy }`.

### Core Services

**`app/services/sender_registration_service.rb`** — `find_or_create_by!(phone_number:)` com rescue `RecordNotUnique` para race condition.

**`app/services/message_concatenation_service.rb`** — O serviço mais complexo:
1. Busca ou inicializa `ConcatenationBuffer` para sender+instance
2. Append texto com `\n`, incrementa count, atualiza `expires_at` para `now + CONCAT_WINDOW`
3. Usa `with_lock` (pessimistic lock) para evitar race conditions
4. Agenda `ConcatenationFlushJob.set(wait_until: expires_at)` com `expected_expires_at`
5. O flush job verifica se `buffer.expires_at == expected_expires_at` — se timer foi resetado por mensagem mais nova, o job é no-op

**`app/services/audio_transcription_service.rb`** — Download do áudio para Tempfile, chama OpenAI Whisper API, retorna `{ text:, tokens_used:, model: }`.

**`app/services/message_audit_service.rb`** — Cria record na tabela `messages` com dados do payload.

Nota: a publicação no `PROCESSED_MESSAGES_QUEUE` é feita pelo `ProcessedMessagePublisher` (em `app/publishers/`), não por um service. Os services delegam a publicação para os publishers.

---

## Fase 6 — Background Jobs

**`app/jobs/incoming_message_job.rb`** — Orquestrador principal. `limits_concurrency to: 1, key: sender_phone` para serializar processamento por sender. Flow:
1. `MessageParser.call(payload)`
2. `SenderRegistrationService.call(...)`
3. `MessageAuditJob.perform_later(...)` (async)
4. `MessageStrategyResolver.resolve(type).new(parsed, sender).call`

**`app/jobs/message_audit_job.rb`** — Queue `:low_priority`. Cria registro de auditoria.

**`app/jobs/concatenation_flush_job.rb`** — Queue `:high_priority`. Verifica se timer expirou, flush do buffer, enqueue resultado, destroy buffer.

**`app/jobs/audio_transcription_job.rb`** — `retry_on TranscriptionError, wait: :polynomially_longer, attempts: 3`. Transcreve, registra token_usage, enqueue resultado.

### Solid Queue Config (`config/queue.yml`)

- `high_priority` — 2 threads, polling 0.5s (ConcatenationFlushJob)
- `default` — 3 threads, polling 1s (IncomingMessageJob, AudioTranscriptionJob)
- `low_priority` — 1 thread, polling 2s (MessageAuditJob)

---

## Fase 7 — Docker

**`Dockerfile`** — Multi-stage (base → build → runtime). Ruby 3.3-slim, libsqlite3, curl, ffmpeg. Non-root user. `bin/docker-entrypoint` roda `db:prepare`.

**`docker-compose.yml`** — 2 services apenas (conecta no RabbitMQ de produção):
- `consumer` — `bin/consumer` (RabbitMQ consumers)
- `worker` — `bundle exec rake solid_queue:start` (background jobs)

Volume compartilhado `sqlite_data` entre consumer e worker. RabbitMQ é externo (produção) — a URL de conexão vem do `RABBITMQ_URL` no `.env`.

Em desenvolvimento, rodar `bin/consumer` e `bin/rails solid_queue:start` diretamente sem Docker, conectando no mesmo RabbitMQ de produção via `RABBITMQ_URL`.

---

## Fase 8 — Testes (RSpec)

### Configuração
- `rails generate rspec:install` → gera `spec/spec_helper.rb`, `spec/rails_helper.rb`, `.rspec`
- `spec/rails_helper.rb` — SimpleCov no topo (minimum 90%, branch coverage)
- `spec/support/payload_helpers.rb` — `build_text_message_payload`, `build_audio_message_payload`
- `spec/support/rabbitmq_test_helper.rb` — `FakePublisher` que grava mensagens publicadas
- Factory Bot com factories em `spec/factories/` para sender, message, token_usage, concatenation_buffer

### Unit Specs
- `spec/services/message_parser_spec.rb` — Parse texto, parse audio, tipo desconhecido, payload malformado
- `spec/services/sender_registration_service_spec.rb` — Cria novo, idempotente, race condition
- `spec/services/message_concatenation_service_spec.rb` — **Crítico**:
  - Mensagem única + window expira
  - Múltiplas mensagens dentro da window → concatenação com `\n`
  - Timer reset (mensagem chega antes de expirar → window estende)
  - Senders independentes têm windows independentes
  - Formato do payload de saída
- `spec/services/audio_transcription_service_spec.rb` — Chamada API stubada (WebMock), retorna texto, falha de API
- `spec/services/message_enqueue_service_spec.rb` — Payload correto, formato exato
- `spec/services/strategies/` — Cada strategy delega para o serviço correto
- `spec/jobs/` — Cada job com cenários normais e de erro
- `spec/models/` — Validações e associações de cada model

### Integration Specs
- `spec/integration/full_message_flow_spec.rb` — Mensagem RabbitMQ in → parse → strategy → enqueue → out

---

## Fase 9 — CI / Pre-Commit

**`bin/ci`**:
```bash
#!/bin/bash
set -e
bundle exec rubocop
bundle exec bundler-audit check --update
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec rspec
```

**`bin/pre-commit`** — Symlink para `.git/hooks/pre-commit`. Roda `bin/ci`.

**`bin/install-hooks`** — Script para instalar o hook. Chamado por `bin/setup`.

---

## Fase 10 — README e Documentação

- Setup local (Ruby, env vars, conexão com RabbitMQ de produção)
- Docker compose up (consumer + worker)
- Variáveis de ambiente (tabela completa)
- Arquitetura (diagrama de fluxo de dados)
- Como rodar testes (`bundle exec rspec`)
- CI / pre-commit hooks

---

## Features Adicionais Sugeridas

1. **Deduplicação de mensagens** — Unique index em `whatsapp_message_id`, checar antes de processar
2. **Bloqueio de senders** — Campo `blocked_at` na tabela senders, impede processamento
3. **Logging estruturado** — Lograge com JSON em produção
4. **Archival/Purge de mensagens** — Job recorrente que limpa mensagens mais velhas que N dias
5. **Dashboard de custo** — Endpoint admin para consumo de tokens por sender

---

## Fluxo de Dados Completo

```
RabbitMQ (<instance>.messages.upsert)
  │
  ▼
MessagesConsumer [app/consumers/] (manual ack, retry via x-retry-count header)
  │  └─► falhas: DeadLetterPublisher [app/publishers/] → DLQ
  ▼
IncomingMessageJob (Solid Queue, concurrency=1 per sender)
  │
  ├─► MessageParser.call(payload) → ParsedMessage
  ├─► SenderRegistrationService.call → Sender (find_or_create)
  ├─► MessageAuditJob.perform_later (async audit)
  │
  └─► MessageStrategyResolver.resolve(message_type)
       │
       ├── "conversation" → ConversationStrategy
       │     └─► MessageConcatenationService
       │           ├─► ConcatenationBuffer (upsert + append)
       │           └─► ConcatenationFlushJob.set(wait_until: expires_at)
       │                 └─► (quando timer expira sem reset)
       │                     ├─► ProcessedMessagePublisher [app/publishers/] → PROCESSED_MESSAGES_QUEUE
       │                     └─► ConcatenationBuffer.destroy!
       │
       └── "audioMessage" → AudioMessageStrategy
             └─► AudioTranscriptionJob
                   ├─► AudioTranscriptionService (OpenAI Whisper)
                   ├─► TokenUsage.create!
                   └─► ProcessedMessagePublisher [app/publishers/] → PROCESSED_MESSAGES_QUEUE
```

---

## Ordem de Implementação

1. Scaffold Rails + Gemfile + database.yml + .env.example + RSpec install
2. Migrations + Models + validações + specs de model
3. Value Objects (ParsedMessage) + MessageParser + specs
4. RabbitMQ layer: `lib/rabbit_mq/connection.rb`, `app/publishers/`, `app/consumers/`, `bin/consumer` + specs
5. SenderRegistrationService + specs
6. MessageAuditService + MessageAuditJob + specs
7. MessageConcatenationService + ConcatenationFlushJob + specs extensivos
8. AudioTranscriptionService + AudioTranscriptionJob + TokenUsage + specs
9. Strategy pattern + MessageStrategyResolver + IncomingMessageJob + specs
10. ProcessedMessagePublisher + specs de formato do payload
11. Docker (Dockerfile, docker-compose.yml, .dockerignore) — sem RabbitMQ, sem web
12. CI (bin/ci, bin/pre-commit, bin/install-hooks)
13. README

---

## Verificação End-to-End

1. Configurar `RABBITMQ_URL` no `.env` apontando para o RabbitMQ de produção
2. Rodar `bin/consumer` localmente — verificar que conecta e consome mensagens
3. Rodar `bin/rails solid_queue:start` em outro terminal
4. Publicar payload de texto na fila de entrada via RabbitMQ management UI
5. Verificar: sender criado, message de auditoria criada, buffer de concatenação existe
6. Esperar window expirar → verificar mensagem processada na fila de saída
7. Publicar payload de áudio (com URL mockada no dev) → verificar transcrição + token_usage
8. Enviar 3 payloads inválidos → verificar DLQ
9. `bin/ci` — todos os checks passam
10. `docker compose up` — verificar que consumer e worker funcionam em containers
