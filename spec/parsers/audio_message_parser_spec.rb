require "rails_helper"

RSpec.describe AudioMessageParser do
  let(:payload) { build_audio_message_payload.deep_symbolize_keys }

  describe ".call" do
    it "returns a ParsedMessage" do
      expect(described_class.call(payload)).to be_a(ValueObjects::ParsedMessage)
    end

    it "extracts media_url" do
      result = described_class.call(payload)
      expect(result.media_url).to eq("https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123")
    end

    it "extracts audio_mimetype" do
      result = described_class.call(payload)
      expect(result.audio_mimetype).to eq("audio/ogg; codecs=opus")
    end

    it "sets message_body to nil" do
      expect(described_class.call(payload).message_body).to be_nil
    end

    it "extracts shared fields correctly" do
      result = described_class.call(payload)
      expect(result.message_type).to eq("audioMessage")
      expect(result.sender_phone_number).to eq("5511999999999")
      expect(result.instance_name).to eq("materny-bot-ai")
    end
  end
end
