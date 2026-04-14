class MessageAuditJob < ApplicationJob
  queue_as :low_priority

  def perform(parsed_message_json:, sender_id:)
    parsed = MessageParser.call(parsed_message_json)
    sender = Sender.find(sender_id)

    MessageAuditService.call(parsed_message: parsed, sender: sender)
  end
end
