class AudioTranscriptionService
  class TranscriptionError < StandardError; end
  class InvalidAudioError < TranscriptionError; end

  def self.call(binary:, mimetype: "audio/ogg")
    new(binary: binary, mimetype: mimetype).call
  end

  def initialize(binary:, mimetype:)
    @binary = binary
    @mimetype = mimetype
  end

  def call
    tempfile = build_tempfile
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

  def build_tempfile
    raise InvalidAudioError, "Audio data is empty" if @binary.empty?

    tempfile = Tempfile.new([ "whisper_audio", resolve_extension ])
    tempfile.binmode
    tempfile.write(@binary)
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
