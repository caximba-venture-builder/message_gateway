class AudioMessageParser < InboundMessageParserBase
  def call
    ValueObjects::ParsedMessage.new(
      event: @payload[:event],
      instance_name: @payload[:instance],
      server_url: @payload[:server_url],
      date_time: @payload[:date_time],
      sender_phone_number: sanitize_phone_number,
      api_key: @payload[:apikey],
      whatsapp_message_id: data.dig(:key, :id),
      remote_jid: data.dig(:key, :remoteJidAlt),
      push_name: PushNameSanitizer.call(data[:pushName]),
      message_type: data[:messageType],
      message_timestamp: data[:messageTimestamp].to_i,
      source_os: data[:source],
      message_body: nil,
      media_url: data.dig(:message, :mediaUrl),
      audio_mimetype: data.dig(:message, :audioMessage, :mimetype),
      raw_payload: @payload
    )
  end
end
