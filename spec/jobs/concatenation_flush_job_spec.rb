require "rails_helper"

RSpec.describe ConcatenationFlushJob, type: :job do
  let(:sender) { create(:sender, phone_number: "5511999999999", push_name: "João") }
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_exchange) { instance_double(Bunny::Exchange) }

  before do
    allow(RabbitMq::Connection).to receive(:instance).and_return(
      instance_double(Bunny::Session, create_channel: mock_channel)
    )
    allow(mock_channel).to receive(:default_exchange).and_return(mock_exchange)
    allow(mock_exchange).to receive(:publish)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("PROCESSED_MESSAGES_QUEUE").and_return("test.processed")
  end

  describe "#perform" do
    context "when buffer exists and timer has expired" do
      let!(:buffer) do
        create(:concatenation_buffer,
          sender: sender,
          instance_name: "materny-bot-ai",
          accumulated_text: "Hello\nWorld",
          expires_at: 1.minute.ago,
          message_count: 2
        )
      end

      it "publishes the concatenated message" do
        described_class.new.perform(
          buffer_id: buffer.id,
          expected_expires_at: buffer.expires_at.iso8601(6)
        )

        expect(mock_exchange).to have_received(:publish)
      end

      it "destroys the buffer after flushing" do
        expect {
          described_class.new.perform(
            buffer_id: buffer.id,
            expected_expires_at: buffer.expires_at.iso8601(6)
          )
        }.to change(ConcatenationBuffer, :count).by(-1)
      end

      it "publishes with the correct payload format" do
        described_class.new.perform(
          buffer_id: buffer.id,
          expected_expires_at: buffer.expires_at.iso8601(6)
        )

        expected = {
          id: sender.id,
          phone_number: "5511999999999",
          text: "Hello\nWorld",
          name: "João"
        }.to_json

        expect(mock_exchange).to have_received(:publish).with(
          expected,
          routing_key: "test.processed",
          persistent: true,
          content_type: "application/json"
        )
      end
    end

    context "when buffer no longer exists (already flushed)" do
      it "returns without error" do
        expect {
          described_class.new.perform(
            buffer_id: SecureRandom.uuid,
            expected_expires_at: Time.current.iso8601(6)
          )
        }.not_to raise_error
      end

      it "does not publish anything" do
        described_class.new.perform(
          buffer_id: SecureRandom.uuid,
          expected_expires_at: Time.current.iso8601(6)
        )

        expect(mock_exchange).not_to have_received(:publish)
      end
    end

    context "when timer was reset by a newer message (stale job)" do
      let!(:buffer) do
        create(:concatenation_buffer,
          sender: sender,
          instance_name: "materny-bot-ai",
          accumulated_text: "Hello",
          expires_at: 5.minutes.from_now,
          message_count: 1
        )
      end

      it "does not flush the buffer" do
        old_expires_at = 1.minute.ago.iso8601(6)

        described_class.new.perform(
          buffer_id: buffer.id,
          expected_expires_at: old_expires_at
        )

        expect(mock_exchange).not_to have_received(:publish)
        expect(ConcatenationBuffer.find_by(id: buffer.id)).to be_present
      end
    end

    context "when buffer hasn't expired yet but expected_expires_at matches" do
      let!(:buffer) do
        create(:concatenation_buffer,
          sender: sender,
          instance_name: "materny-bot-ai",
          accumulated_text: "Hello",
          expires_at: 5.seconds.from_now,
          message_count: 1
        )
      end

      it "re-schedules the flush job" do
        expect {
          described_class.new.perform(
            buffer_id: buffer.id,
            expected_expires_at: buffer.expires_at.iso8601(6)
          )
        }.to have_enqueued_job(described_class)
      end

      it "does not publish yet" do
        described_class.new.perform(
          buffer_id: buffer.id,
          expected_expires_at: buffer.expires_at.iso8601(6)
        )

        expect(mock_exchange).not_to have_received(:publish)
      end
    end

    it "is enqueued on the high_priority queue" do
      expect {
        described_class.perform_later(
          buffer_id: "some-id",
          expected_expires_at: Time.current.iso8601(6)
        )
      }.to have_enqueued_job.on_queue("high_priority")
    end

    context "when buffer is destroyed between find and with_lock (concurrent flush)" do
      let!(:buffer) do
        create(:concatenation_buffer,
          sender: sender,
          instance_name: "materny-bot-ai",
          accumulated_text: "Hello",
          expires_at: 1.minute.ago,
          message_count: 1
        )
      end

      it "silently ignores RecordNotFound from concurrent destruction" do
        allow_any_instance_of(ConcatenationBuffer).to receive(:with_lock)
          .and_raise(ActiveRecord::RecordNotFound)

        expect {
          described_class.new.perform(
            buffer_id: buffer.id,
            expected_expires_at: buffer.expires_at.iso8601(6)
          )
        }.not_to raise_error

        expect(mock_exchange).not_to have_received(:publish)
      end
    end

    context "when buffer expires_at is still in the future inside the lock (concurrent update)" do
      let!(:buffer) do
        create(:concatenation_buffer,
          sender: sender,
          instance_name: "materny-bot-ai",
          accumulated_text: "Hello",
          expires_at: 1.minute.ago,
          message_count: 1
        )
      end

      it "does not publish when expires_at has been pushed forward inside the lock" do
        # Simulate a concurrent message updating expires_at between the outer check and with_lock
        allow_any_instance_of(ConcatenationBuffer).to receive(:with_lock) do |buf, &block|
          buf.expires_at = 5.minutes.from_now
          block.call
        end

        described_class.new.perform(
          buffer_id: buffer.id,
          expected_expires_at: buffer.expires_at.iso8601(6)
        )

        expect(mock_exchange).not_to have_received(:publish)
      end
    end
  end
end
