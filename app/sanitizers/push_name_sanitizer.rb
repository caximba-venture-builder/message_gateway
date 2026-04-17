class PushNameSanitizer
  MAX_BYTES = 100
  CONTROL_CHARS = /[\r\n\x00-\x1F\x7F]/.freeze

  def self.call(raw)
    new(raw).call
  end

  def initialize(raw)
    @raw = raw
  end

  def call
    cleaned = @raw.to_s
                  .dup
                  .force_encoding(Encoding::UTF_8)
                  .scrub("")
                  .unicode_normalize(:nfc)
                  .gsub(CONTROL_CHARS, "")

    return cleaned if cleaned.bytesize <= MAX_BYTES

    cleaned.byteslice(0, MAX_BYTES).to_s.force_encoding(Encoding::UTF_8).scrub("")
  end
end
