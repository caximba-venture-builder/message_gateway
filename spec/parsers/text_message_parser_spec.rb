require "rails_helper"

RSpec.describe TextMessageParser do
  let(:payload) { build_text_message_payload.deep_symbolize_keys }

  describe ".call" do
    it "returns a ParsedMessage" do
      expect(described_class.call(payload)).to be_a(ValueObjects::ParsedMessage)
    end

    it "extracts message_body from conversation field" do
      result = described_class.call(payload)
      expect(result.message_body).to eq("Olá, tudo bem?")
    end

    it "sets media_url to nil" do
      expect(described_class.call(payload).media_url).to be_nil
    end

    it "sets audio_mimetype to nil" do
      expect(described_class.call(payload).audio_mimetype).to be_nil
    end

    it "extracts shared fields correctly" do
      result = described_class.call(payload)
      expect(result.message_type).to eq("conversation")
      expect(result.sender_phone_number).to eq("5511999999999")
      expect(result.instance_name).to eq("materny-bot-ai")
    end
  end
end
