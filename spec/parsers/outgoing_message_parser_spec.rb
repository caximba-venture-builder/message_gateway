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

    context "with phone_number without country code" do
      let(:body) { { "phone_number" => "41999341900", "text" => "Olá!" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /country code/)
      end
    end

    context "with non-numeric phone_number" do
      let(:body) { { "phone_number" => "+5511999999999", "text" => "Olá!" }.to_json }

      it "raises ParseError" do
        expect { described_class.call(body) }.to raise_error(OutgoingMessageParser::ParseError, /country code/)
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
