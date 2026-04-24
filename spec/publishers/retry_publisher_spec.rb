require "rails_helper"

RSpec.describe RetryPublisher do
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_exchange) { instance_double(Bunny::Exchange) }
  let(:mock_connection) { instance_double(Bunny::Session, create_channel: mock_channel) }

  before do
    allow(RabbitMq::Connection).to receive(:instance).and_return(mock_connection)
    allow(mock_channel).to receive(:default_exchange).and_return(mock_exchange)
    allow(mock_exchange).to receive(:publish)
  end

  describe ".publish" do
    it "publishes the raw body to the given queue with the retry header" do
      described_class.publish(
        queue_name: "test-bot.messages.upsert",
        body: '{"hello":"world"}',
        retry_count: 2
      )

      expect(mock_exchange).to have_received(:publish).with(
        '{"hello":"world"}',
        routing_key: "test-bot.messages.upsert",
        persistent: true,
        content_type: "application/json",
        headers: { "x-retry-count" => 2 }
      )
    end

    it "closes the channel after publishing" do
      described_class.publish(queue_name: "q", body: "{}", retry_count: 1)
      expect(mock_channel).to have_received(:close)
    end

    it "propagates errors so the consumer can nack" do
      allow(mock_exchange).to receive(:publish).and_raise(Bunny::ConnectionClosedError.new(nil))

      expect {
        described_class.publish(queue_name: "q", body: "{}", retry_count: 1)
      }.to raise_error(Bunny::ConnectionClosedError)
    end
  end
end
