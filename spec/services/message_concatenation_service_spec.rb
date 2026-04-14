require "rails_helper"

RSpec.describe MessageConcatenationService do
  let(:sender) { create(:sender) }
  let(:instance_name) { "materny-bot-ai" }

  before do
    stub_const("MessageConcatenationService::CONCAT_WINDOW", 15)
  end

  describe ".call" do
    it "creates a concatenation buffer for a new sender" do
      expect {
        described_class.call(sender: sender, instance_name: instance_name, text: "Hello")
      }.to change(ConcatenationBuffer, :count).by(1)
    end

    it "stores the text in the buffer" do
      described_class.call(sender: sender, instance_name: instance_name, text: "Hello")

      buffer = ConcatenationBuffer.last
      expect(buffer.accumulated_text).to eq("Hello")
      expect(buffer.message_count).to eq(1)
    end

    it "sets expires_at to CONCAT_WINDOW seconds from now" do
      freeze_time do
        described_class.call(sender: sender, instance_name: instance_name, text: "Hello")

        buffer = ConcatenationBuffer.last
        expect(buffer.expires_at).to be_within(1.second).of(15.seconds.from_now)
      end
    end

    it "schedules a ConcatenationFlushJob" do
      expect {
        described_class.call(sender: sender, instance_name: instance_name, text: "Hello")
      }.to have_enqueued_job(ConcatenationFlushJob)
    end

    context "multiple messages within the window" do
      it "concatenates text with newline separator" do
        described_class.call(sender: sender, instance_name: instance_name, text: "Hello")
        described_class.call(sender: sender, instance_name: instance_name, text: "World")

        buffer = ConcatenationBuffer.last
        expect(buffer.accumulated_text).to eq("Hello\nWorld")
        expect(buffer.message_count).to eq(2)
      end

      it "concatenates three messages correctly" do
        described_class.call(sender: sender, instance_name: instance_name, text: "A")
        described_class.call(sender: sender, instance_name: instance_name, text: "B")
        described_class.call(sender: sender, instance_name: instance_name, text: "C")

        buffer = ConcatenationBuffer.last
        expect(buffer.accumulated_text).to eq("A\nB\nC")
        expect(buffer.message_count).to eq(3)
      end

      it "does not create multiple buffers for the same sender + instance" do
        described_class.call(sender: sender, instance_name: instance_name, text: "Hello")
        described_class.call(sender: sender, instance_name: instance_name, text: "World")

        expect(ConcatenationBuffer.count).to eq(1)
      end
    end

    context "timer reset" do
      it "resets expires_at with each new message" do
        freeze_time do
          described_class.call(sender: sender, instance_name: instance_name, text: "First")
          first_expiry = ConcatenationBuffer.last.expires_at

          travel 10.seconds

          described_class.call(sender: sender, instance_name: instance_name, text: "Second")
          second_expiry = ConcatenationBuffer.last.expires_at

          expect(second_expiry).to be > first_expiry
          expect(second_expiry).to be_within(1.second).of(15.seconds.from_now)
        end
      end

      it "schedules a new flush job for each message" do
        expect {
          described_class.call(sender: sender, instance_name: instance_name, text: "First")
          described_class.call(sender: sender, instance_name: instance_name, text: "Second")
        }.to have_enqueued_job(ConcatenationFlushJob).exactly(2).times
      end
    end

    context "independent senders" do
      let(:sender2) { create(:sender) }

      it "maintains separate buffers per sender" do
        described_class.call(sender: sender, instance_name: instance_name, text: "From sender 1")
        described_class.call(sender: sender2, instance_name: instance_name, text: "From sender 2")

        expect(ConcatenationBuffer.count).to eq(2)

        buffer1 = ConcatenationBuffer.find_by(sender: sender)
        buffer2 = ConcatenationBuffer.find_by(sender: sender2)

        expect(buffer1.accumulated_text).to eq("From sender 1")
        expect(buffer2.accumulated_text).to eq("From sender 2")
      end
    end

    context "different instances" do
      it "maintains separate buffers per instance" do
        described_class.call(sender: sender, instance_name: "bot-a", text: "Text A")
        described_class.call(sender: sender, instance_name: "bot-b", text: "Text B")

        expect(ConcatenationBuffer.count).to eq(2)
      end
    end
  end
end
