class MessageAuditJob < ApplicationJob
  queue_as :low_priority

  discard_on ActiveRecord::RecordNotFound

  def perform(whatsapp_message_id:, message_type:, message_timestamp:, source_os:, sender_id:)
    sender = Sender.find(sender_id)

    MessageAuditService.call(
      whatsapp_message_id: whatsapp_message_id,
      message_type: message_type,
      message_timestamp: message_timestamp,
      source_os: source_os,
      sender: sender
    )
  end
end
