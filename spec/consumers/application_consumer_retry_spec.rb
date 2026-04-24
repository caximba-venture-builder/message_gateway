require "rails_helper"

RSpec.describe ApplicationConsumer do
  let(:queue_name) { "test-bot.messages.upsert" }
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }

  # Create a concrete subclass for testing
  let(:consumer_class) do
    Class.new(ApplicationConsumer) do
      attr_accessor :handler_behavior

      private

      def handle_message(body, properties)
        case handler_behavior
        when :success then nil
        when :error then raise StandardError, "Processing failed"
        when :parse then JSON.parse(body) # will fail on invalid JSON
        end
      end
    end
  end

  let(:consumer) do
    c = consumer_class.new(queue_name: queue_name)
    c.handler_behavior = :success
    c
  end

  let(:delivery_info) { double(delivery_tag: "tag-1") }

  before do
    allow(mock_channel).to receive(:ack)
    allow(mock_channel).to receive(:nack)
    allow(RetryPublisher).to receive(:publish)
    allow(DeadLetterPublisher).to receive(:publish)
  end

  describe "retry logic" do
    context "when processing fails with retry count < MAX_RETRIES" do
      let(:properties) { double(headers: { "x-retry-count" => 1 }) }

      before { consumer.handler_behavior = :error }

      it "republishes with incremented retry count via RetryPublisher" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(RetryPublisher).to have_received(:publish).with(
          queue_name: queue_name,
          body: '{"test": true}',
          retry_count: 2
        )
      end

      it "acks only after a successful republish" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
        expect(mock_channel).not_to have_received(:nack)
      end
    end

    context "when processing fails and retry count >= MAX_RETRIES" do
      let(:properties) { double(headers: { "x-retry-count" => 3 }) }

      before { consumer.handler_behavior = :error }

      it "sends to dead letter queue" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')

        expect(DeadLetterPublisher).to have_received(:publish).with(
          source_queue: queue_name,
          body: '{"test": true}',
          retry_count: 3,
          error_message: "Processing failed"
        )
      end

      it "acks only after a successful DLQ publish" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
        expect(mock_channel).not_to have_received(:nack)
      end
    end

    context "when body is invalid JSON" do
      let(:properties) { double(headers: nil) }

      before { consumer.handler_behavior = :parse }

      it "sends directly to DLQ without retrying" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, "not valid json")

        expect(DeadLetterPublisher).to have_received(:publish).with(
          source_queue: queue_name,
          body: "not valid json",
          retry_count: 0,
          error_message: a_string_matching(/unexpected token/)
        )
        expect(RetryPublisher).not_to have_received(:publish)
      end

      it "acks after the DLQ publish succeeds" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, "not valid json")
        expect(mock_channel).to have_received(:ack).with("tag-1")
      end
    end

    context "when RetryPublisher fails" do
      let(:properties) { double(headers: { "x-retry-count" => 0 }) }

      before do
        consumer.handler_behavior = :error
        allow(RetryPublisher).to receive(:publish).and_raise(RuntimeError, "channel open failed")
      end

      it "nacks with requeue so the message is not lost" do
        expect {
          consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        }.not_to raise_error

        expect(mock_channel).to have_received(:nack).with("tag-1", false, true)
        expect(mock_channel).not_to have_received(:ack)
      end
    end

    context "when DeadLetterPublisher fails on max-retries path" do
      let(:properties) { double(headers: { "x-retry-count" => 3 }) }

      before do
        consumer.handler_behavior = :error
        allow(DeadLetterPublisher).to receive(:publish).and_raise(RuntimeError, "dlq down")
      end

      it "nacks with requeue so the message is not lost" do
        expect {
          consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        }.not_to raise_error

        expect(mock_channel).to have_received(:nack).with("tag-1", false, true)
        expect(mock_channel).not_to have_received(:ack)
      end
    end

    context "when DeadLetterPublisher fails on invalid-JSON path" do
      let(:properties) { double(headers: nil) }

      before do
        consumer.handler_behavior = :parse
        allow(DeadLetterPublisher).to receive(:publish).and_raise(RuntimeError, "dlq down")
      end

      it "nacks with requeue so the message is not lost" do
        expect {
          consumer.send(:process_delivery, mock_channel, delivery_info, properties, "not valid json")
        }.not_to raise_error

        expect(mock_channel).to have_received(:nack).with("tag-1", false, true)
        expect(mock_channel).not_to have_received(:ack)
      end
    end

    context "when processing succeeds" do
      let(:properties) { double(headers: nil) }

      it "acks the message" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
      end

      it "does not publish to DLQ or retry" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(DeadLetterPublisher).not_to have_received(:publish)
        expect(RetryPublisher).not_to have_received(:publish)
      end
    end
  end
end
