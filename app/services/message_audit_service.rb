class MessageAuditService
  def self.call(whatsapp_message_id:, message_type:, message_timestamp:, source_os:, sender:)
    Message.create!(
      whatsapp_message_id: whatsapp_message_id,
      message_type: message_type,
      sender: sender,
      message_timestamp: message_timestamp,
      sender_os: source_os
    )
  end
end
