class IncomingMessageJob < ApplicationJob
  queue_as :default

  discard_on MessageParser::ParseError

  def perform(payload:, instance_name:)
    return if payload.dig("data", "key", "fromMe")

    parsed = MessageParser.call(payload)

    sender = SenderRegistrationService.call(
      phone_number: parsed.sender_phone_number,
      push_name: parsed.push_name,
      os: parsed.source_os
    )

    MessageAuditJob.perform_later(
      parsed_message_json: payload,
      sender_id: sender.id
    )

    strategy_class = MessageStrategyResolver.resolve(parsed.message_type)
    strategy_class.new(parsed, sender).call
  end
end
