require "rails_helper"

RSpec.describe SenderRegistrationService do
  describe ".call" do
    it "creates a new sender for a new phone number" do
      expect {
        described_class.call(
          phone_number: "5511999999999",
          push_name: "João Silva",
          os: "android"
        )
      }.to change(Sender, :count).by(1)
    end

    it "returns the created sender" do
      sender = described_class.call(
        phone_number: "5511999999999",
        push_name: "João Silva",
        os: "android"
      )

      expect(sender).to be_a(Sender)
      expect(sender.phone_number).to eq("5511999999999")
      expect(sender.push_name).to eq("João Silva")
      expect(sender.os).to eq("android")
    end

    it "returns existing sender for known phone number" do
      existing = create(:sender, phone_number: "5511999999999")

      result = described_class.call(
        phone_number: "5511999999999",
        push_name: "Different Name",
        os: "ios"
      )

      expect(result.id).to eq(existing.id)
      expect(Sender.count).to eq(1)
    end

    it "does not update existing sender data" do
      create(:sender, phone_number: "5511999999999", push_name: "Original Name")

      result = described_class.call(
        phone_number: "5511999999999",
        push_name: "Different Name",
        os: "ios"
      )

      expect(result.push_name).to eq("Original Name")
    end

    it "generates a UUID for the sender id" do
      sender = described_class.call(
        phone_number: "5511999999999",
        push_name: "João",
        os: "android"
      )

      expect(sender.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "handles different phone numbers independently" do
      sender1 = described_class.call(phone_number: "5511111111111", push_name: "User1", os: "android")
      sender2 = described_class.call(phone_number: "5522222222222", push_name: "User2", os: "ios")

      expect(sender1.id).not_to eq(sender2.id)
      expect(Sender.count).to eq(2)
    end
  end
end
