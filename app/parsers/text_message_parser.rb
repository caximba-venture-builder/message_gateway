class TextMessageParser
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
      sender_phone_number: @payload[:sender]&.split("@")&.first,
      api_key: @payload[:apikey],
      whatsapp_message_id: data.dig(:key, :id),
      remote_jid: data.dig(:key, :remoteJid),
      push_name: data[:pushName],
      message_type: data[:messageType],
      message_timestamp: data[:messageTimestamp].to_i,
      source_os: data[:source],
      message_body: data.dig(:message, :conversation),
      media_url: nil,
      audio_mimetype: nil,
      raw_payload: @payload
    )
  end

  private

  def data
    @payload[:data]
  end
end
