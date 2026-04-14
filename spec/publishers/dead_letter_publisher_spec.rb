require "rails_helper"

RSpec.describe DeadLetterPublisher do
  let(:publisher) { described_class.new }

  describe "#publish" do
    let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
    let(:mock_exchange) { instance_double(Bunny::Exchange) }

    before do
      allow(RabbitMq::Connection).to receive(:instance).and_return(
        instance_double(Bunny::Session, create_channel: mock_channel)
      )
      allow(mock_channel).to receive(:default_exchange).and_return(mock_exchange)
      allow(mock_exchange).to receive(:publish)
    end

    it "publishes to the DLQ with .dlq suffix" do
      publisher.publish(
        source_queue: "my-bot.messages.upsert",
        body: '{"test": true}',
        retry_count: 3,
        error_message: "Something failed"
      )

      expect(mock_exchange).to have_received(:publish).with(
        anything,
        hash_including(routing_key: "my-bot.messages.upsert.dlq")
      )
    end

    it "includes error metadata in the payload" do
      freeze_time do
        publisher.publish(
          source_queue: "my-bot.messages.upsert",
          body: '{"test": true}',
          retry_count: 3,
          error_message: "Something failed"
        )

        expected = {
          original_message: { "test" => true },
          error: "Something failed",
          retry_count: 3,
          failed_at: Time.current.iso8601,
          source_queue: "my-bot.messages.upsert"
        }.to_json

        expect(mock_exchange).to have_received(:publish).with(
          expected,
          routing_key: "my-bot.messages.upsert.dlq",
          persistent: true,
          content_type: "application/json"
        )
      end
    end

    it "handles unparseable body gracefully" do
      publisher.publish(
        source_queue: "test.queue",
        body: "not json",
        retry_count: 0,
        error_message: "Parse error"
      )

      expect(mock_exchange).to have_received(:publish)
    end
  end
end
