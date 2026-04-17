class TextSanitizer
  class TextTooLargeError < StandardError; end

  TRUNCATION_MARKER = "…[truncated]".freeze
  CONTROL_CHARS = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/.freeze

  def self.call(raw, max_bytes:, mode: :truncate)
    new(raw, max_bytes: max_bytes, mode: mode).call
  end

  def initialize(raw, max_bytes:, mode:)
    @raw = raw
    @max_bytes = max_bytes
    @mode = mode
  end

  def call
    cleaned = normalize(@raw)
    return cleaned if cleaned.bytesize <= @max_bytes

    case @mode
    when :raise
      raise TextTooLargeError,
            "text exceeds max size of #{@max_bytes} bytes (got #{cleaned.bytesize})"
    when :truncate
      truncate(cleaned)
    else
      raise ArgumentError, "unknown mode: #{@mode.inspect}"
    end
  end

  private

  def normalize(raw)
    raw.to_s
       .dup
       .force_encoding(Encoding::UTF_8)
       .scrub("")
       .unicode_normalize(:nfc)
       .gsub(CONTROL_CHARS, "")
  end

  def truncate(cleaned)
    budget = [ @max_bytes - TRUNCATION_MARKER.bytesize, 0 ].max
    truncated = cleaned.byteslice(0, budget).to_s.force_encoding(Encoding::UTF_8).scrub("")
    "#{truncated}#{TRUNCATION_MARKER}"
  end
end
