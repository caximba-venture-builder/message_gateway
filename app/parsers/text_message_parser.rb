class TextMessageParser
  MAX_INBOUND_TEXT_BYTES = 4096

  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload
  end

  def call
    ValueObjects::ParsedMessage.new(
      event: @payload[:event],
      instance_name: @payload[:instance],
      server_url: @payload[:server_url],
      date_time: @payload[:date_time],
      sender_phone_number: sanitize_phone_number,
      api_key: @payload[:apikey],
      whatsapp_message_id: data.dig(:key, :id),
      remote_jid: data.dig(:key, :remoteJid),
      push_name: PushNameSanitizer.call(data[:pushName]),
      message_type: data[:messageType],
      message_timestamp: data[:messageTimestamp].to_i,
      source_os: data[:source],
      message_body: TextSanitizer.call(data.dig(:message, :conversation), max_bytes: MAX_INBOUND_TEXT_BYTES),
      media_url: nil,
      audio_mimetype: nil,
      raw_payload: @payload
    )
  end

  private

  def data
    @payload[:data]
  end

  def sanitize_phone_number
    raw = @payload[:sender]&.split("@")&.first
    PhoneNumberSanitizer.call(raw)
  rescue PhoneNumberSanitizer::InvalidPhoneNumberError => e
    raise MessageParser::ParseError, "Invalid sender phone_number: #{e.message}"
  end
end
