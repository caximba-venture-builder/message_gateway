class AudioTranscriptionService
  class TranscriptionError < StandardError; end

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

  def download_audio
    extension = resolve_extension
    tempfile = Tempfile.new([ "whisper_audio", extension ])
    tempfile.binmode

    uri = URI.parse(@audio_url)
    response = Net::HTTP.get_response(uri)
    raise TranscriptionError, "Audio download failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    tempfile.write(response.body)
    tempfile.rewind
    tempfile
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
