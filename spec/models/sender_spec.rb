require "rails_helper"

RSpec.describe Sender, type: :model do
  subject { build(:sender) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires phone_number" do
      subject.phone_number = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:phone_number]).to include("can't be blank")
    end

    it "requires push_name" do
      subject.push_name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:push_name]).to include("can't be blank")
    end

    it "enforces unique phone_number" do
      create(:sender, phone_number: "5511999999999")
      subject.phone_number = "5511999999999"
      expect(subject).not_to be_valid
      expect(subject.errors[:phone_number]).to include("has already been taken")
    end

    it "does not require os" do
      subject.os = nil
      expect(subject).to be_valid
    end
  end

  describe "associations" do
    it "has many messages" do
      sender = create(:sender)
      create(:message, sender: sender)
      expect(sender.messages.count).to eq(1)
    end

    it "has many token_usages" do
      sender = create(:sender)
      message = create(:message, sender: sender)
      create(:token_usage, sender: sender, message: message)
      expect(sender.token_usages.count).to eq(1)
    end

    it "has many concatenation_buffers" do
      sender = create(:sender)
      create(:concatenation_buffer, sender: sender)
      expect(sender.concatenation_buffers.count).to eq(1)
    end

    it "destroys dependent messages" do
      sender = create(:sender)
      create(:message, sender: sender)
      expect { sender.destroy }.to change(Message, :count).by(-1)
    end
  end

  describe "UUID primary key" do
    it "generates a UUID id on create" do
      sender = create(:sender)
      expect(sender.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end
  end
end
