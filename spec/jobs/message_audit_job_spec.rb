require "rails_helper"

RSpec.describe MessageAuditJob, type: :job do
  let(:sender) { create(:sender, phone_number: "5511999999999") }
  let(:args) do
    {
      whatsapp_message_id: "3EB0A0C1D2E3F4A5B6C7D8",
      message_type: "conversation",
      message_timestamp: 1713105000,
      source_os: "android",
      sender_id: sender.id
    }
  end

  describe "#perform" do
    it "creates an audit message record" do
      expect {
        described_class.new.perform(**args)
      }.to change(Message, :count).by(1)
    end

    it "creates a message with correct attributes" do
      described_class.new.perform(**args)

      message = Message.last
      expect(message.whatsapp_message_id).to eq("3EB0A0C1D2E3F4A5B6C7D8")
      expect(message.message_type).to eq("conversation")
      expect(message.sender_id).to eq(sender.id)
    end

    it "is enqueued on the low_priority queue" do
      expect {
        described_class.perform_later(**args)
      }.to have_enqueued_job.on_queue("low_priority")
    end
  end
end
