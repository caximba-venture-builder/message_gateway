require "rails_helper"

RSpec.describe Message, type: :model do
  subject { build(:message) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires whatsapp_message_id" do
      subject.whatsapp_message_id = nil
      expect(subject).not_to be_valid
    end

    it "requires message_type" do
      subject.message_type = nil
      expect(subject).not_to be_valid
    end

    it "validates message_type inclusion" do
      subject.message_type = "unknown"
      expect(subject).not_to be_valid
      expect(subject.errors[:message_type]).to include("is not included in the list")
    end

    it "accepts conversation type" do
      subject.message_type = "conversation"
      expect(subject).to be_valid
    end

    it "accepts audioMessage type" do
      subject.message_type = "audioMessage"
      expect(subject).to be_valid
    end

    it "requires message_timestamp" do
      subject.message_timestamp = nil
      expect(subject).not_to be_valid
    end

    it "requires sender" do
      subject.sender = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to sender" do
      message = create(:message)
      expect(message.sender).to be_a(Sender)
    end
  end

  describe "UUID primary key" do
    it "generates a UUID id on create" do
      message = create(:message)
      expect(message.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end
end
