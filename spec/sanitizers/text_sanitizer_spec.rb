require "rails_helper"

RSpec.describe TextSanitizer do
  describe ".call" do
    it "returns the string unchanged when within limits" do
      expect(described_class.call("hello", max_bytes: 100)).to eq("hello")
    end

    it "preserves newline and tab characters" do
      expect(described_class.call("line1\nline2\tend", max_bytes: 100)).to eq("line1\nline2\tend")
    end

    it "strips NUL bytes" do
      expect(described_class.call("abc\u0000def", max_bytes: 100)).to eq("abcdef")
    end

    it "strips C0 control characters except newline and tab" do
      expect(described_class.call("a\x01b\x08c\x0Bd\x1Fe", max_bytes: 100)).to eq("abcde")
    end

    it "strips the DEL character" do
      expect(described_class.call("a\x7Fb", max_bytes: 100)).to eq("ab")
    end

    it "scrubs invalid UTF-8 bytes" do
      invalid = "abc\xFFdef".dup.force_encoding(Encoding::UTF_8)
      expect(described_class.call(invalid, max_bytes: 100)).to eq("abcdef")
    end

    it "normalizes to NFC" do
      decomposed = "a\u0301"
      composed = "á"
      expect(described_class.call(decomposed, max_bytes: 100)).to eq(composed)
    end

    it "coerces non-string input with to_s" do
      expect(described_class.call(42, max_bytes: 100)).to eq("42")
    end

    context "with mode: :truncate (default)" do
      it "truncates and appends the marker when exceeding max_bytes" do
        input = "a" * 50
        result = described_class.call(input, max_bytes: 20)
        expect(result).to end_with("…[truncated]")
        expect(result.bytesize).to be <= 20
      end

      it "respects multibyte character boundaries when truncating" do
        input = "日" * 50
        result = described_class.call(input, max_bytes: 30)
        expect(result).to be_valid_encoding
        expect(result).to end_with("…[truncated]")
      end

      it "handles max_bytes smaller than the marker size" do
        result = described_class.call("abcdefghijklmnop", max_bytes: 5)
        expect(result).to end_with("…[truncated]")
      end
    end

    context "with mode: :raise" do
      it "raises TextTooLargeError when exceeding max_bytes" do
        expect {
          described_class.call("a" * 50, max_bytes: 10, mode: :raise)
        }.to raise_error(TextSanitizer::TextTooLargeError, /exceeds max size of 10 bytes/)
      end

      it "returns the cleaned string when within limits" do
        expect(described_class.call("hello", max_bytes: 100, mode: :raise)).to eq("hello")
      end
    end

    context "with an unknown mode" do
      it "raises ArgumentError" do
        expect {
          described_class.call("a" * 50, max_bytes: 10, mode: :bogus)
        }.to raise_error(ArgumentError, /unknown mode/)
      end
    end
  end
end
