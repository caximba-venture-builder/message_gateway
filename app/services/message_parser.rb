class MessageParser
  class ParseError < StandardError; end

  SUPPORTED_MESSAGE_TYPES = %w[conversation audioMessage].freeze

  def self.call(raw_payload)
    new(raw_payload).call
  end

  def initialize(raw_payload)
    @payload = raw_payload.deep_symbolize_keys
  end

  def call
    validate!

    ValueObjects::ParsedMessage.new(
      event: @payload[:event],
      instance_name: @payload[:instance],
      server_url: @payload[:server_url],
      date_time: @payload[:date_time],
      sender_phone_number: extract_phone_number,
      api_key: @payload[:apikey],
      whatsapp_message_id: data.dig(:key, :id),
      remote_jid: data.dig(:key, :remoteJid),
      push_name: data[:pushName],
      message_type: data[:messageType],
      message_timestamp: data[:messageTimestamp].to_i,
      source_os: data[:source],
      message_body: extract_message_body,
      audio_url: extract_audio_url,
      audio_mimetype: data.dig(:message, :audioMessage, :mimetype),
      audio_file_length: data.dig(:message, :audioMessage, :fileLength),
      audio_message: extract_audio_message,
      raw_payload: @payload
    )
  end

  private

  def data
    @payload[:data]
  end

  def extract_phone_number
    @payload[:sender]&.split("@")&.first
  end

  def extract_message_body
    return nil unless data[:messageType] == "conversation"
    data.dig(:message, :conversation)
  end

  def extract_audio_url
    return nil unless data[:messageType] == "audioMessage"
    data.dig(:message, :audioMessage, :url)
  end

  def extract_audio_message
    return nil unless data[:messageType] == "audioMessage"
    data[:message]&.deep_stringify_keys
  end

  def validate!
    raise ParseError, "Missing 'data' field" unless data.is_a?(Hash)
    raise ParseError, "Missing 'sender' field" unless @payload[:sender].present?
    raise ParseError, "Missing 'data.key.id'" unless data.dig(:key, :id).present?
    raise ParseError, "Missing 'data.messageType'" unless data[:messageType].present?
    raise ParseError, "Unsupported messageType: #{data[:messageType]}" unless SUPPORTED_MESSAGE_TYPES.include?(data[:messageType])
  end
end
