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

    case data[:messageType]
    when "conversation" then TextMessageParser.call(@payload)
    when "audioMessage" then AudioMessageParser.call(@payload)
    end
  end

  private

  def data
    @payload[:data]
  end

  def validate!
    raise ParseError, "Missing 'data' field" unless data.is_a?(Hash)
    raise ParseError, "Missing 'sender' field" unless @payload[:sender].present?
    raise ParseError, "Missing 'data.key.id'" unless data.dig(:key, :id).present?
    raise ParseError, "Missing 'data.messageType'" unless data[:messageType].present?
    raise ParseError, "Unsupported messageType: #{data[:messageType]}" unless SUPPORTED_MESSAGE_TYPES.include?(data[:messageType])
  end
end
