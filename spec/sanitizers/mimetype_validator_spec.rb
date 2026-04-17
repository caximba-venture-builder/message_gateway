require "rails_helper"

RSpec.describe MimetypeValidator do
  describe ".call!" do
    it "returns normalized value for audio/ogg" do
      expect(described_class.call!("audio/ogg")).to eq("audio/ogg")
    end

    it "strips parameters after a semicolon" do
      expect(described_class.call!("audio/ogg; codecs=opus")).to eq("audio/ogg")
    end

    it "downcases the input" do
      expect(described_class.call!("AUDIO/MPEG")).to eq("audio/mpeg")
    end

    it "accepts audio/mp4" do
      expect(described_class.call!("audio/mp4")).to eq("audio/mp4")
    end

    it "accepts audio/webm" do
      expect(described_class.call!("audio/webm")).to eq("audio/webm")
    end

    it "accepts audio/wav" do
      expect(described_class.call!("audio/wav")).to eq("audio/wav")
    end

    it "raises InvalidMimetypeError for an unknown mimetype" do
      expect {
        described_class.call!("application/json")
      }.to raise_error(MimetypeValidator::InvalidMimetypeError, /not in allowlist/)
    end

    it "raises InvalidMimetypeError for nil input" do
      expect {
        described_class.call!(nil)
      }.to raise_error(MimetypeValidator::InvalidMimetypeError)
    end

    it "raises InvalidMimetypeError for an empty string" do
      expect {
        described_class.call!("")
      }.to raise_error(MimetypeValidator::InvalidMimetypeError)
    end
  end
end
