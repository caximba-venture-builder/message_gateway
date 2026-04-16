class OutgoingMessageParser
  class ParseError < StandardError; end

  def self.call(raw_body)
    new(raw_body).call
  end

  def initialize(raw_body)
    @payload = JSON.parse(raw_body)
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON: #{e.message}"
  end

  def call
    phone_number = @payload.fetch("phone_number") { raise ParseError, "Missing 'phone_number' field" }

    unless phone_number.to_s.match?(/\A\d{12,}\z/)
      raise ParseError, "Invalid 'phone_number': must contain only digits and include country code (e.g. 5511999999999)"
    end

    {
      phone_number: phone_number,
      text: @payload.fetch("text") { raise ParseError, "Missing 'text' field" }
    }
  end
end
