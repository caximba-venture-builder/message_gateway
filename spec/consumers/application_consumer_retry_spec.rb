require "rails_helper"

RSpec.describe ApplicationConsumer do
  let(:queue_name) { "test-bot.messages.upsert" }
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_queue) { instance_double(Bunny::Queue) }
  let(:mock_dlq_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_dlq_queue) { instance_double(Bunny::Queue) }

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
    allow(RabbitMq::Connection).to receive(:instance).and_return(
      instance_double(Bunny::Session, create_channel: mock_channel)
    )
    allow(mock_channel).to receive(:queue).and_return(mock_queue)
    allow(mock_channel).to receive(:ack)
    allow(mock_queue).to receive(:publish)

    # For DLQ publishing
    allow(DeadLetterPublisher).to receive(:publish)
  end

  describe "retry logic" do
    context "when processing fails with retry count < MAX_RETRIES" do
      let(:properties) { double(headers: { "x-retry-count" => 1 }) }

      before { consumer.handler_behavior = :error }

      it "acks the original message" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
      end

      it "republishes with incremented retry count" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_queue).to have_received(:publish).with(
          '{"test": true}',
          hash_including(headers: { "x-retry-count" => 2 })
        )
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

      it "acks the original message" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
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
      end
    end

    context "when processing succeeds" do
      let(:properties) { double(headers: nil) }

      it "acks the message" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(mock_channel).to have_received(:ack).with("tag-1")
      end

      it "does not publish to DLQ" do
        consumer.send(:process_delivery, mock_channel, delivery_info, properties, '{"test": true}')
        expect(DeadLetterPublisher).not_to have_received(:publish)
      end
    end
  end
end
