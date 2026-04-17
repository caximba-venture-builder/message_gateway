require "rails_helper"

RSpec.describe InstanceNameValidator do
  describe ".call!" do
    it "accepts a simple lowercase name" do
      expect(described_class.call!("materny-bot-ai")).to eq("materny-bot-ai")
    end

    it "accepts names with digits and underscores" do
      expect(described_class.call!("bot_01")).to eq("bot_01")
    end

    it "rejects names starting with a hyphen" do
      expect {
        described_class.call!("-bot")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects names containing a slash (path traversal)" do
      expect {
        described_class.call!("../../bot")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects names containing whitespace" do
      expect {
        described_class.call!("bot name")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects uppercase letters" do
      expect {
        described_class.call!("MyBot")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects empty strings" do
      expect {
        described_class.call!("")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects nil" do
      expect {
        described_class.call!(nil)
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects names longer than 64 characters" do
      expect {
        described_class.call!("a" * 65)
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "accepts names of exactly 64 characters" do
      name = "a" * 64
      expect(described_class.call!(name)).to eq(name)
    end
  end
end
