require "rails_helper"

RSpec.describe MessageAuditService do
  describe ".call" do
    let(:sender) { create(:sender) }
    let(:args) do
      {
        whatsapp_message_id: "3EB0A0C1D2E3F4A5B6C7D8",
        message_type: "conversation",
        message_timestamp: 1713105000,
        source_os: "android",
        sender: sender
      }
    end

    it "creates a Message record" do
      expect {
        described_class.call(**args)
      }.to change(Message, :count).by(1)
    end

    it "sets the correct attributes" do
      message = described_class.call(**args)

      expect(message.whatsapp_message_id).to eq("3EB0A0C1D2E3F4A5B6C7D8")
      expect(message.message_type).to eq("conversation")
      expect(message.sender_id).to eq(sender.id)
      expect(message.message_timestamp).to eq(1713105000)
      expect(message.sender_os).to eq("android")
    end

    it "generates a UUID for the message id" do
      message = described_class.call(**args)
      expect(message.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    context "with audio message" do
      it "sets message_type to audioMessage" do
        message = described_class.call(**args.merge(message_type: "audioMessage"))
        expect(message.message_type).to eq("audioMessage")
      end
    end
  end
end
