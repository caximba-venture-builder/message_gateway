class AudioTranscriptionService
  class TranscriptionError < StandardError; end
  class InvalidAudioError < TranscriptionError; end

  def self.call(audio_url:, mimetype: "audio/ogg")
    new(audio_url: audio_url, mimetype: mimetype).call
  end

  def initialize(audio_url:, mimetype:)
    @audio_url = audio_url
    @mimetype = mimetype
  end

  def call
    tempfile = download_audio
    response = transcribe(tempfile)

    {
      text: response.dig("text"),
      tokens_used: extract_token_count(response),
      model: transcription_model
    }
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  private

  MAX_REDIRECTS = 5

  def download_audio
    extension = resolve_extension
    tempfile = Tempfile.new([ "whisper_audio", extension ])
    tempfile.binmode

    response = fetch_with_redirects(URI.parse(@audio_url))
    raise TranscriptionError, "Audio download failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    content_type = response["content-type"].to_s
    if content_type.include?("text/html") || content_type.include?("application/json")
      raise InvalidAudioError, "Audio URL returned non-audio content (#{content_type}). URL may have expired or require authentication."
    end

    tempfile.write(response.body)
    tempfile.rewind

    Rails.logger.info("[AudioTranscriptionService] Downloaded #{tempfile.size} bytes (#{content_type}) from #{@audio_url}")
    raise InvalidAudioError, "Downloaded audio file is empty" if tempfile.size.zero?

    tempfile
  end

  def fetch_with_redirects(uri, redirects_remaining = MAX_REDIRECTS)
    raise TranscriptionError, "Too many redirects downloading audio" if redirects_remaining.zero?

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri)
    end

    if response.is_a?(Net::HTTPRedirection)
      location = URI.parse(response["location"])
      location = uri + location if location.relative?
      fetch_with_redirects(location, redirects_remaining - 1)
    else
      response
    end
  end

  def transcribe(tempfile)
    client = OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"))
    response = client.audio.transcribe(
      parameters: {
        model: transcription_model,
        file: tempfile,
        language: ENV.fetch("OPENAI_TRANSCRIPTION_LANGUAGE", "pt")
      }
    )

    raise TranscriptionError, "Transcription failed: #{response}" unless response["text"].present?
    response
  rescue Faraday::BadRequestError => e
    body = e.response&.dig(:body) || e.message
    raise InvalidAudioError, "OpenAI rejected the audio (400): #{body}"
  end

  def transcription_model
    ENV.fetch("OPENAI_TRANSCRIPTION_MODEL", "whisper-1")
  end

  def resolve_extension
    base_mime = @mimetype.split(";").first.strip
    case base_mime
    when "audio/ogg" then ".ogg"
    when "audio/mpeg" then ".mp3"
    when "audio/mp4" then ".m4a"
    when "audio/wav" then ".wav"
    else ".ogg"
    end
  end

  def extract_token_count(response)
    response.dig("usage", "total_tokens") || estimate_tokens(response["text"])
  end

  def estimate_tokens(text)
    (text.to_s.length / 4.0).ceil
  end
end
