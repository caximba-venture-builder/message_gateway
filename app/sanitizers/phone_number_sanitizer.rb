class PhoneNumberSanitizer
  class InvalidPhoneNumberError < StandardError; end

  VALID_LENGTH = (10..15).freeze

  def self.call(raw)
    new(raw).call
  end

  def initialize(raw)
    @raw = raw
  end

  def call
    digits = @raw.to_s.delete("^0-9")

    unless VALID_LENGTH.cover?(digits.length)
      raise InvalidPhoneNumberError,
            "phone_number must contain #{VALID_LENGTH.min}..#{VALID_LENGTH.max} digits (got #{digits.length})"
    end

    digits
  end
end
