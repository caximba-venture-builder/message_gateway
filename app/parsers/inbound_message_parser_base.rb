class InboundMessageParserBase
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload
  end

  def call
    raise NotImplementedError, "Subclasses must implement #call"
  end

  private

  def data
    @payload[:data]
  end

  def sanitize_phone_number
    raw = data.dig(:key, :remoteJid)&.split("@")&.first
    PhoneNumberSanitizer.call(raw)
  rescue PhoneNumberSanitizer::InvalidPhoneNumberError => e
    raise MessageParser::ParseError, "Invalid sender phone_number: #{e.message}"
  end
end
