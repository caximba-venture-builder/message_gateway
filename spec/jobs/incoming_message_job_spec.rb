require "rails_helper"

RSpec.describe IncomingMessageJob, type: :job do
  let(:text_payload) { build_text_message_payload }
  let(:audio_payload) { build_audio_message_payload }

  describe "#perform" do
    context "with a conversation message" do
      it "creates a sender" do
        expect {
          described_class.new.perform(payload: text_payload, instance_name: "materny-bot-ai")
        }.to change(Sender, :count).by(1)
      end

      it "enqueues a MessageAuditJob" do
        expect {
          described_class.new.perform(payload: text_payload, instance_name: "materny-bot-ai")
        }.to have_enqueued_job(MessageAuditJob)
      end

      it "delegates to ConversationStrategy via concatenation" do
        expect(MessageConcatenationService).to receive(:call)

        described_class.new.perform(payload: text_payload, instance_name: "materny-bot-ai")
      end

      it "creates the sender with correct attributes" do
        described_class.new.perform(payload: text_payload, instance_name: "materny-bot-ai")

        sender = Sender.last
        expect(sender.phone_number).to eq("5511999999999")
        expect(sender.push_name).to eq("João Silva")
        expect(sender.os).to eq("android")
      end
    end

    context "with an audio message" do
      it "enqueues an AudioTranscriptionJob" do
        expect {
          described_class.new.perform(payload: audio_payload, instance_name: "materny-bot-ai")
        }.to have_enqueued_job(AudioTranscriptionJob)
      end
    end

    context "when sender already exists" do
      before do
        create(:sender, phone_number: "5511999999999", push_name: "João Silva")
      end

      it "does not create a duplicate sender" do
        expect {
          described_class.new.perform(payload: text_payload, instance_name: "materny-bot-ai")
        }.not_to change(Sender, :count)
      end
    end
  end
end
