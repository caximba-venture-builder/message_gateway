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
      whatsapp_message_id: parsed.whatsapp_message_id,
      message_type: parsed.message_type,
      message_timestamp: parsed.message_timestamp,
      source_os: parsed.source_os,
      sender_id: sender.id
    )

    strategy_class = MessageStrategyResolver.resolve(parsed.message_type)
    strategy_class.new(parsed, sender).call
  end
end
