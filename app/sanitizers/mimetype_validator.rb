class MimetypeValidator
  class InvalidMimetypeError < StandardError; end

  ALLOWED = Set.new(%w[audio/ogg audio/mpeg audio/mp4 audio/webm audio/wav]).freeze

  def self.call!(raw)
    new(raw).call!
  end

  def initialize(raw)
    @raw = raw
  end

  def call!
    normalized = @raw.to_s.downcase.split(";").first.to_s.strip

    unless ALLOWED.include?(normalized)
      raise InvalidMimetypeError, "mimetype #{normalized.inspect} is not in allowlist"
    end

    normalized
  end
end
