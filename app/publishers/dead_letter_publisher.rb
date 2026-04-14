class DeadLetterPublisher < ApplicationPublisher
  def publish(source_queue:, body:, retry_count:, error_message:)
    dlq_payload = {
      original_message: parse_body(body),
      error: error_message,
      retry_count: retry_count,
      failed_at: Time.current.iso8601,
      source_queue: source_queue
    }

    dlq_name = "#{source_queue}.dlq"

    with_channel do |channel|
      publish_to_queue(channel, dlq_name, dlq_payload)
    end
  end

  private

  def parse_body(body)
    JSON.parse(body)
  rescue JSON::ParserError
    body
  end
end
