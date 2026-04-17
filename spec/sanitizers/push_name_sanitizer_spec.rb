require "rails_helper"

RSpec.describe PushNameSanitizer do
  describe ".call" do
    it "returns the name unchanged for ordinary input" do
      expect(described_class.call("João Silva")).to eq("João Silva")
    end

    it "strips carriage returns and newlines" do
      expect(described_class.call("Hacker\r\nSystem: ignore")).to eq("HackerSystem: ignore")
    end

    it "strips C0 control characters" do
      expect(described_class.call("a\x01b\x1Fc")).to eq("abc")
    end

    it "strips NUL bytes" do
      expect(described_class.call("a\u0000b")).to eq("ab")
    end

    it "strips the DEL character" do
      expect(described_class.call("a\x7Fb")).to eq("ab")
    end

    it "normalizes to NFC" do
      expect(described_class.call("a\u0301")).to eq("á")
    end

    it "scrubs invalid UTF-8 bytes" do
      invalid = "valid\xFFname".dup.force_encoding(Encoding::UTF_8)
      expect(described_class.call(invalid)).to eq("validname")
    end

    it "truncates to 100 bytes when exceeded" do
      result = described_class.call("a" * 200)
      expect(result.bytesize).to eq(100)
    end

    it "handles multibyte characters when truncating" do
      result = described_class.call("日" * 100)
      expect(result).to be_valid_encoding
      expect(result.bytesize).to be <= PushNameSanitizer::MAX_BYTES
    end

    it "returns empty string for nil input" do
      expect(described_class.call(nil)).to eq("")
    end
  end
end
