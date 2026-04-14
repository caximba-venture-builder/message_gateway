require "rails_helper"

RSpec.describe AudioTranscriptionService do
  let(:audio_url) { "https://mmg.whatsapp.net/v/t62.7114-24/audio.ogg" }
  let(:audio_body) { "fake audio content" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_return("sk-test-key")
    allow(ENV).to receive(:fetch).with("OPENAI_TRANSCRIPTION_MODEL", "whisper-1").and_return("whisper-1")
    allow(ENV).to receive(:fetch).with("OPENAI_TRANSCRIPTION_LANGUAGE", "pt").and_return("pt")
  end

  describe ".call" do
    context "with a successful transcription" do
      before do
        stub_request(:get, audio_url)
          .to_return(status: 200, body: audio_body)

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "Olá, como vai?" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns the transcribed text" do
        result = described_class.call(audio_url: audio_url)
        expect(result[:text]).to eq("Olá, como vai?")
      end

      it "estimates token count when not provided by API" do
        result = described_class.call(audio_url: audio_url)
        expect(result[:tokens_used]).to be_a(Integer)
        expect(result[:tokens_used]).to be > 0
      end

      it "returns the model name" do
        result = described_class.call(audio_url: audio_url)
        expect(result[:model]).to eq("whisper-1")
      end
    end

    context "with token usage from API" do
      before do
        stub_request(:get, audio_url)
          .to_return(status: 200, body: audio_body)

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: {
              "text" => "Hello",
              "usage" => { "total_tokens" => 42 }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "uses the API-provided token count" do
        result = described_class.call(audio_url: audio_url)
        expect(result[:tokens_used]).to eq(42)
      end
    end

    context "when audio download fails" do
      before do
        stub_request(:get, audio_url)
          .to_return(status: 404, body: "Not Found")
      end

      it "raises TranscriptionError" do
        expect {
          described_class.call(audio_url: audio_url)
        }.to raise_error(AudioTranscriptionService::TranscriptionError, /Audio download failed: HTTP 404/)
      end
    end

    context "when transcription returns empty text" do
      before do
        stub_request(:get, audio_url)
          .to_return(status: 200, body: audio_body)

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises TranscriptionError" do
        expect {
          described_class.call(audio_url: audio_url)
        }.to raise_error(AudioTranscriptionService::TranscriptionError, /Transcription failed/)
      end
    end

    context "with different mimetypes" do
      before do
        stub_request(:get, audio_url)
          .to_return(status: 200, body: audio_body)

        stub_request(:post, "https://api.openai.com/v1/audio/transcriptions")
          .to_return(
            status: 200,
            body: { "text" => "Test" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles audio/ogg mimetype" do
        result = described_class.call(audio_url: audio_url, mimetype: "audio/ogg; codecs=opus")
        expect(result[:text]).to eq("Test")
      end

      it "handles audio/mpeg mimetype" do
        result = described_class.call(audio_url: audio_url, mimetype: "audio/mpeg")
        expect(result[:text]).to eq("Test")
      end
    end
  end
end
