require "rails_helper"

RSpec.describe DeadLetterPublisher do
  let(:publisher) { described_class.new }

  describe "#publish" do
    let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
    let(:mock_queue) { instance_double(Bunny::Queue) }

    before do
      allow(RabbitMq::Connection).to receive(:instance).and_return(
        instance_double(Bunny::Session, create_channel: mock_channel)
      )
      allow(mock_channel).to receive(:queue).and_return(mock_queue)
      allow(mock_queue).to receive(:publish)
    end

    it "publishes to the DLQ with .dlq suffix" do
      publisher.publish(
        source_queue: "my-bot.messages.upsert",
        body: '{"test": true}',
        retry_count: 3,
        error_message: "Something failed"
      )

      expect(mock_channel).to have_received(:queue).with("my-bot.messages.upsert.dlq", durable: true)
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

        expect(mock_queue).to have_received(:publish).with(
          expected,
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

      expect(mock_queue).to have_received(:publish)
    end
  end
end
