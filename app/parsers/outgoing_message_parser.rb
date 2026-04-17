class OutgoingMessageParser
  class ParseError < StandardError; end

  MAX_OUTBOUND_TEXT_BYTES = 8192

  def self.call(raw_body)
    new(raw_body).call
  end

  def initialize(raw_body)
    @payload = JSON.parse(raw_body)
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON: #{e.message}"
  end

  def call
    {
      phone_number: sanitize_phone_number,
      text: sanitize_text
    }
  end

  private

  def sanitize_phone_number
    raw = @payload.fetch("phone_number") { raise ParseError, "Missing 'phone_number' field" }
    PhoneNumberSanitizer.call(raw)
  rescue PhoneNumberSanitizer::InvalidPhoneNumberError => e
    raise ParseError, "Invalid 'phone_number': #{e.message}"
  end

  def sanitize_text
    raw = @payload.fetch("text") { raise ParseError, "Missing 'text' field" }
    TextSanitizer.call(raw, max_bytes: MAX_OUTBOUND_TEXT_BYTES, mode: :raise)
  rescue TextSanitizer::TextTooLargeError => e
    raise ParseError, "Invalid 'text': #{e.message}"
  end
end
