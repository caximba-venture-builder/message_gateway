require "rails_helper"

RSpec.describe OutgoingMessageParser do
  describe ".call" do
    context "with a valid payload" do
      let(:body) { { "phone_number" => "5511999999999", "text" => "Olá!" }.to_json }

      it "returns a hash with phone_number and text" do
        result = described_class.call(body)
        expect(result).to eq(phone_number: "5511999999999", text: "Olá!")
      end
    end

    context "with phone_number containing a leading +" do
      let(:body) { { "phone_number" => "+5511999999999", "text" => "Olá!" }.to_json }

      it "strips non-digits and returns the sanitized number" do
        result = described_class.call(body)
        expect(result[:phone_number]).to eq("5511999999999")
      end
    end

    context "with phone_number shorter than 10 digits" do
      let(:body) { { "phone_number" => "12345", "text" => "Olá!" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /phone_number/)
      end
    end

    context "with phone_number longer than 15 digits" do
      let(:body) { { "phone_number" => "1234567890123456", "text" => "Olá!" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /phone_number/)
      end
    end

    context "with text exceeding 8192 bytes" do
      let(:body) { { "phone_number" => "5511999999999", "text" => "a" * 8193 }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /text/)
      end
    end

    context "with text containing control characters" do
      let(:body) { { "phone_number" => "5511999999999", "text" => "hi\u0000\u0001there" }.to_json }

      it "strips control characters" do
        result = described_class.call(body)
        expect(result[:text]).to eq("hithere")
      end
    end

    context "with missing phone_number" do
      let(:body) { { "text" => "Olá!" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /phone_number/)
      end
    end

    context "with missing text" do
      let(:body) { { "phone_number" => "5511999999999" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /text/)
      end
    end

    context "with invalid JSON" do
      it "raises ParseError" do
        expect { described_class.call("not json") }.to raise_error(OutgoingMessageParser::ParseError, /Invalid JSON/)
      end
    end
  end
end
