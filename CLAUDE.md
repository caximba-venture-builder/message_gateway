# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Message broker/gateway for WhatsApp via Evolution API. Consumes messages from RabbitMQ queues, concatenates text messages from the same sender within a configurable sliding time window, transcribes audio messages via OpenAI Whisper, and publishes processed messages to another RabbitMQ queue. This is a background processing daemon, not a REST API -- the only HTTP endpoint is a health check at `/up`.

**Stack:** Ruby 3.4.3, Rails 8.1 (API-only), SQLite3 (WAL mode), Solid Queue/Cache/Cable, Bunny (RabbitMQ), ruby-openai (Whisper), Lograge.

## Commands

```bash
# Setup
bin/setup                        # Install deps, prepare DB, install git hooks

# Running locally (two terminals)
bin/consumer                     # RabbitMQ message consumer
bin/jobs                         # Solid Queue background job processor

# Tests
bundle exec rspec                # Full suite
bundle exec rspec spec/path      # Single file or directory
bundle exec rspec spec/path:42   # Single example by line number

# Linting & security
bundle exec rubocop              # Lint (rubocop-rails-omakase + rubocop-rspec)
bundle exec rubocop -a           # Lint with auto-fix
bundle exec brakeman             # Security scan
bundle exec bundler-audit check  # Dependency audit

# CI (runs rubocop, bundler-audit, brakeman, rspec)
bin/ci

# Database
bin/rails db:prepare             # Idempotent setup (create + migrate + seed)

# Docker
docker compose up --build        # consumer + worker containers sharing SQLite volume
```

## Architecture

The message flow is: **RabbitMQ -> Consumer -> Solid Queue Job -> Strategy -> Publisher -> RabbitMQ**.

**Consumer layer** (`app/consumers/`): `ConsumerManager` starts one `MessagesConsumer` per queue listed in `RABBITMQ_QUEUES`. Consumers use manual ACK with prefetch(1). Retry count is tracked via `x-retry-count` message headers (not DLX) -- after `MESSAGE_MAX_RETRY_COUNT` failures, messages go to `<queue>.dlq` via `DeadLetterPublisher`.

**Job orchestration** (`app/jobs/`): `IncomingMessageJob` is the main coordinator -- it parses the payload into a `ParsedMessage` value object (Ruby `Data.define`), registers the sender, enqueues an async audit job, then dispatches to the appropriate strategy.

**Strategy pattern** (`app/services/strategies/`): `MessageStrategyResolver` routes by `message_type`:
- `"conversation"` -> `ConversationStrategy` -> `MessageConcatenationService`: appends text to a `ConcatenationBuffer` with a sliding window timer. Each message resets `expires_at`. A delayed `ConcatenationFlushJob` checks whether the timer truly expired (stale jobs are no-ops).
- `"audioMessage"` -> `AudioMessageStrategy` -> `AudioTranscriptionJob`: downloads audio, calls OpenAI Whisper, records `TokenUsage`, publishes result.

**Publisher layer** (`app/publishers/`): `ProcessedMessagePublisher` sends `{id, phone_number, text, name}` to `PROCESSED_MESSAGES_QUEUE`. `DeadLetterPublisher` sends failed messages with error context to `<queue>.dlq`.

**RabbitMQ connection** (`lib/rabbit_mq/connection.rb`): Thread-safe singleton via Mutex + Bunny with automatic recovery (10 attempts, 5s interval, 30s heartbeat).

### Database

SQLite3 with separate databases for primary data, Solid Queue, Solid Cache, and Action Cable (see `config/database.yml`). All databases live in `storage/` and use WAL mode to reduce write contention.

## Coding Conventions

### Models

Follow this ordering within model files:

```ruby
class ModelName < ApplicationRecord
  # 1. Associations
  has_many / belongs_to

  # 2. Validations
  validates :field, presence: true

  # 3. Scopes
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # 4. Callbacks (inherited from ApplicationRecord for UUID)

  # 5. Public instance methods

  # 6. Private methods
end
```

Key patterns:
- All models inherit from `ApplicationRecord`, which sets UUID string primary keys via `before_create :set_uuid` using `SecureRandom.uuid`
- Use `Time.current` (never `Time.now`) for time comparisons
- Scopes use inline lambda syntax
- Validations: `:presence`, `:uniqueness`, `:numericality`, `:inclusion`
- `message_type` is validated with `inclusion: { in: %w[conversation audioMessage] }`

### Services

```ruby
class SomeService
  def self.call(...)
    new(...).call
  end

  def initialize(keyword_args)
    # assign instance variables
  end

  def call
    # business logic
  end
end
```

Key patterns:
- Entry point is always `ServiceName.call(keyword_args:)` class method, which delegates to `new.call`
- Parameters are keyword arguments
- Custom exceptions defined inside the service class: `class ParseError < StandardError; end`
- Race condition handling: rescue `ActiveRecord::RecordNotUnique` and retry (see `SenderRegistrationService`)
- Resource cleanup in `ensure` blocks (temp files, RabbitMQ channels)

### Jobs

```ruby
class SomeJob < ApplicationJob
  queue_as :default  # or :low_priority, :high_priority

  retry_on SpecificError, wait: :polynomially_longer, attempts: 3

  def perform(keyword_args)
    # guard clause for stale state
    return if stale_condition?
    # actual work
  end
end
```

Key patterns:
- Three queue priorities: `:default`, `:low_priority` (audit), `:high_priority` (flush)
- Guard clauses at the top of `perform` for stale or deleted records
- `ConcatenationFlushJob` receives `expected_expires_at` and compares with current buffer state to detect stale scheduled jobs
- `retry_on` with specific exception classes (not blanket retries)
- Jobs delegate to services -- they don't contain business logic inline

### Consumers

- `ApplicationConsumer` is the base class with full error handling and retry infrastructure
- Subclasses implement `#handle_message(parsed_body, delivery_info, properties)` -- the abstract interface
- `JSON::ParserError` sends directly to DLQ (no retries); `StandardError` triggers retry loop
- Max retries from `ENV["MESSAGE_MAX_RETRY_COUNT"]` (default: 3)
- Each consumer creates its own channel with `prefetch(1)` and `manual_ack: true`

### Publishers

- `ApplicationPublisher` provides factory pattern: `self.publish(...)` creates instance and calls `#publish`
- `with_channel` private method yields a Bunny channel and ensures cleanup
- `publish_to_queue` handles JSON serialization and persistent delivery
- Subclasses build their own payload hash and call `publish_to_queue`

### Strategies

- All strategies inherit `Strategies::BaseStrategy` which takes `(parsed_message, sender)` and requires `#call`
- `MessageStrategyResolver.resolve(message_type)` returns the strategy class from a `STRATEGIES` hash constant
- Usage: `strategy_class.new(parsed, sender).call`
- Adding a new message type = add a new strategy class + register it in the resolver hash

### Value Objects

- Use Ruby `Data.define` (immutable) under `ValueObjects::` namespace
- `ParsedMessage` is the single value object, created by `MessageParser` from raw Evolution API webhook payloads
- Pure data containers with no methods

### Tests

**Framework:** RSpec 7.1 + FactoryBot + WebMock + SimpleCov (80% min, branch coverage)

**Spec structure mirrors app structure:**
```
spec/
  models/         # Model unit tests
  services/       # Service unit tests
  jobs/           # Job unit tests
  consumers/      # Consumer tests
  lib/            # Library tests
  factories/      # FactoryBot definitions
  support/        # Test helpers
```

**Factory conventions:**
- Faker for unique values: `phone_number { Faker::PhoneNumber.unique.phone_number.gsub(/\D/, "") }`
- Traits for message type variants: `trait :conversation`, `trait :audio`
- Associations by factory name: `sender` (implicit)

**Test helpers (`spec/support/`):**
- `PayloadHelpers`: `build_text_message_payload(overrides = {})` and `build_audio_message_payload(overrides = {})` build full Evolution API payloads with `.deep_merge(overrides)` for test flexibility
- `FakePublisher`: Captures published RabbitMQ messages in-memory for assertions. Provides `messages`, `last_message`, `messages_for(queue_name)`, `reset!`

**Included in all specs via `rails_helper.rb`:**
- `FactoryBot::Syntax::Methods` (use `create`, `build` directly)
- `ActiveSupport::Testing::TimeHelpers` (`travel_to`, `freeze_time`)
- `ActiveJob::TestHelper` (`have_enqueued_job`)
- `WebMock` disables external connections (allows localhost)

### Migrations

- All tables use string UUID primary keys (not auto-increment)
- Add indexes on lookup columns (`whatsapp_message_id`, `phone_number`, `expires_at`)
- Use `null: false` on required columns

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `RABBITMQ_URL` | AMQP connection URL | `amqp://guest:guest@localhost:5672` |
| `RABBITMQ_QUEUES` | Comma-separated queue names to consume | _(required)_ |
| `PROCESSED_MESSAGES_QUEUE` | Queue name for processed output messages | _(required)_ |
| `MESSAGE_CONVERSATION_CONCAT_WINDOW` | Seconds to wait before flushing | `30` |
| `MESSAGE_MAX_RETRY_COUNT` | Max retries before sending to DLQ | `3` |
| `OPENAI_API_KEY` | OpenAI API key for Whisper transcription | _(required)_ |
| `OPENAI_TRANSCRIPTION_MODEL` | Whisper model name | `whisper-1` |
| `OPENAI_TRANSCRIPTION_LANGUAGE` | Language hint for transcription | `pt` |
| `SECRET_KEY_BASE` | Rails secret key | _(required in production)_ |

## Pre-Commit Checklist

The pre-commit hook (`bin/pre-commit`, installed by `bin/setup`) runs these automatically on staged Ruby files:

1. `bundle exec rubocop` -- zero offenses
2. `bundle exec brakeman` -- no warnings
3. `bundle exec bundler-audit check` -- no vulnerable gems
4. `bundle exec rspec` -- all tests pass
