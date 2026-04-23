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
      text: response["text"],
      tokens_used: TranscriptionTokenExtractor.call(response),
      model: transcription_model
    }
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  private

  def build_tempfile
    AudioFileBuilder.call(binary: @binary, mimetype: @mimetype)
  rescue AudioFileBuilder::EmptyAudioError => e
    raise InvalidAudioError, e.message
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
end
