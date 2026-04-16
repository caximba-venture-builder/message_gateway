require "rails_helper"

RSpec.describe AudioTranscriptionService do
  let(:audio_binary) { "fake ogg audio content".b }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("sk-test-key")
    allow(ENV).to receive(:fetch).with("OPENAI_TRANSCRIPTION_MODEL", "whisper-1").and_return("whisper-1")
    allow(ENV).to receive(:fetch).with("OPENAI_TRANSCRIPTION_LANGUAGE", "pt").and_return("pt")
  end

  describe ".call" do
    context "with a successful transcription" do
      before do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "Olá, como vai?" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns the transcribed text" do
        result = described_class.call(binary: audio_binary)
        expect(result[:text]).to eq("Olá, como vai?")
      end

      it "estimates token count when not provided by API" do
        result = described_class.call(binary: audio_binary)
        expect(result[:tokens_used]).to be_a(Integer)
        expect(result[:tokens_used]).to be > 0
      end

      it "returns the model name" do
        result = described_class.call(binary: audio_binary)
        expect(result[:model]).to eq("whisper-1")
      end
    end

    context "with token usage from API" do
      before do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "Hello", "usage" => { "total_tokens" => 42 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "uses the API-provided token count" do
        result = described_class.call(binary: audio_binary)
        expect(result[:tokens_used]).to eq(42)
      end
    end

    context "when binary is empty" do
      it "raises InvalidAudioError" do
        expect {
          described_class.call(binary: "".b)
        }.to raise_error(AudioTranscriptionService::InvalidAudioError, /empty/)
      end
    end

    context "when transcription returns empty text" do
      before do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises TranscriptionError" do
        expect {
          described_class.call(binary: audio_binary)
        }.to raise_error(AudioTranscriptionService::TranscriptionError, /Transcription failed/)
      end
    end

    context "with different mimetypes" do
      before do
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "Test" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles audio/ogg mimetype" do
        result = described_class.call(binary: audio_binary, mimetype: "audio/ogg; codecs=opus")
        expect(result[:text]).to eq("Test")
      end

      it "handles audio/mpeg mimetype" do
        result = described_class.call(binary: audio_binary, mimetype: "audio/mpeg")
        expect(result[:text]).to eq("Test")
      end

      it "handles audio/mp4 mimetype" do
        result = described_class.call(binary: audio_binary, mimetype: "audio/mp4")
        expect(result[:text]).to eq("Test")
      end

      it "handles audio/wav mimetype" do
        result = described_class.call(binary: audio_binary, mimetype: "audio/wav")
        expect(result[:text]).to eq("Test")
      end

      it "defaults to .ogg extension for unknown mimetypes" do
        result = described_class.call(binary: audio_binary, mimetype: "audio/unknown")
        expect(result[:text]).to eq("Test")
      end
    end

    context "when OpenAI returns 400 Bad Request with response body" do
      before do
        error_response = { status: 400, headers: {}, body: '{"error":{"message":"Invalid file format."}}' }
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_raise(Faraday::BadRequestError.new("bad request", error_response))
      end

      it "raises InvalidAudioError including the body" do
        expect {
          described_class.call(binary: audio_binary)
        }.to raise_error(AudioTranscriptionService::InvalidAudioError, /OpenAI rejected the audio \(400\)/)
      end
    end

    context "when OpenAI returns 400 Bad Request without a response object" do
      before do
        err = Faraday::BadRequestError.new("bad request")
        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_raise(err)
      end

      it "raises InvalidAudioError using the exception message as fallback" do
        expect {
          described_class.call(binary: audio_binary)
        }.to raise_error(AudioTranscriptionService::InvalidAudioError, /OpenAI rejected the audio \(400\)/)
      end
    end
  end
end
