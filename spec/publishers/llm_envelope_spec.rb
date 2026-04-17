require "rails_helper"

RSpec.describe LlmEnvelope do
  describe ".enabled?" do
    it "returns false by default" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("LLM_ENVELOPE_ENABLED", "false").and_return("false")
      expect(described_class.enabled?).to be false
    end

    it "returns true when ENV is \"true\"" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("LLM_ENVELOPE_ENABLED", "false").and_return("true")
      expect(described_class.enabled?).to be true
    end
  end

  describe ".wrap" do
    it "wraps text in <user_message> tags" do
      result = described_class.wrap(text: "hello", name: "alice")
      expect(result[:text]).to eq("<user_message>hello</user_message>")
      expect(result[:name]).to eq("alice")
    end

    it "escapes &, <, > in text" do
      result = described_class.wrap(text: "<script>&tag>", name: "a")
      expect(result[:text]).to eq("<user_message>&lt;script&gt;&amp;tag&gt;</user_message>")
    end

    it "escapes &, <, > in name" do
      result = described_class.wrap(text: "hi", name: "<Evil & Co>")
      expect(result[:name]).to eq("&lt;Evil &amp; Co&gt;")
    end

    it "escapes & before < and > to avoid double-encoding" do
      result = described_class.wrap(text: "a&b<c", name: "x")
      expect(result[:text]).to eq("<user_message>a&amp;b&lt;c</user_message>")
    end

    it "coerces nil values to empty strings" do
      result = described_class.wrap(text: nil, name: nil)
      expect(result[:text]).to eq("<user_message></user_message>")
      expect(result[:name]).to eq("")
    end
  end
end
