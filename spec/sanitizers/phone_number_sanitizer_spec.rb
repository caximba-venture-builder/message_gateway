require "rails_helper"

RSpec.describe PhoneNumberSanitizer do
  describe ".call" do
    it "returns digits unchanged for a valid number" do
      expect(described_class.call("5511999999999")).to eq("5511999999999")
    end

    it "strips a leading plus sign" do
      expect(described_class.call("+5511999999999")).to eq("5511999999999")
    end

    it "strips spaces, dashes, and parentheses" do
      expect(described_class.call("+55 (11) 99999-9999")).to eq("5511999999999")
    end

    it "strips interleaved non-digit characters" do
      expect(described_class.call("abc5511999999999xyz")).to eq("5511999999999")
    end

    it "accepts the minimum length of 10 digits" do
      expect(described_class.call("1234567890")).to eq("1234567890")
    end

    it "accepts the maximum length of 15 digits" do
      expect(described_class.call("123456789012345")).to eq("123456789012345")
    end

    it "raises InvalidPhoneNumberError for fewer than 10 digits" do
      expect {
        described_class.call("123456789")
      }.to raise_error(PhoneNumberSanitizer::InvalidPhoneNumberError, /10..15 digits/)
    end

    it "raises InvalidPhoneNumberError for more than 15 digits" do
      expect {
        described_class.call("1234567890123456")
      }.to raise_error(PhoneNumberSanitizer::InvalidPhoneNumberError)
    end

    it "raises InvalidPhoneNumberError for nil input" do
      expect {
        described_class.call(nil)
      }.to raise_error(PhoneNumberSanitizer::InvalidPhoneNumberError)
    end

    it "raises InvalidPhoneNumberError for input with only letters" do
      expect {
        described_class.call("abcdefghij")
      }.to raise_error(PhoneNumberSanitizer::InvalidPhoneNumberError, /got 0/)
    end
  end
end
