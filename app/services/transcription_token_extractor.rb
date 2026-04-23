class TranscriptionTokenExtractor
  CHARS_PER_TOKEN = 4.0

  def self.call(response)
    response.dig("usage", "total_tokens") || estimate(response["text"])
  end

  def self.estimate(text)
    (text.to_s.length / CHARS_PER_TOKEN).ceil
  end
end
