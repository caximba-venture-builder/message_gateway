class MessageAuditService
  def self.call(parsed_message:, sender:)
    Message.create!(
      whatsapp_message_id: parsed_message.whatsapp_message_id,
      message_type: parsed_message.message_type,
      sender: sender,
      message_timestamp: parsed_message.message_timestamp,
      sender_os: parsed_message.source_os
    )
  end
end
