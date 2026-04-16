require "rails_helper"

RSpec.describe ApplicationPublisher do
  # Concrete subclass for testing protected methods
  let(:test_publisher_class) do
    Class.new(described_class) do
      def publish(payload:, queue_name:)
        with_channel do |channel|
          publish_to_queue(channel, queue_name, payload)
        end
      end
    end
  end

  let(:publisher) { test_publisher_class.new }
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_exchange) { instance_double(Bunny::Exchange) }

  before do
    allow(RabbitMq::Connection).to receive(:instance).and_return(
      instance_double(Bunny::Session, create_channel: mock_channel)
    )
    allow(mock_channel).to receive(:default_exchange).and_return(mock_exchange)
    allow(mock_exchange).to receive(:publish)
  end

  describe "#publish_to_queue" do
    it "passes a Hash payload as JSON" do
      publisher.publish(payload: { key: "value" }, queue_name: "test.queue")

      expect(mock_exchange).to have_received(:publish).with(
        { key: "value" }.to_json,
        hash_including(routing_key: "test.queue")
      )
    end

    it "passes a String payload as-is without double-encoding" do
      pre_encoded = '{"already":"json"}'
      publisher.publish(payload: pre_encoded, queue_name: "test.queue")

      expect(mock_exchange).to have_received(:publish).with(
        pre_encoded,
        hash_including(routing_key: "test.queue")
      )
    end

    it "closes the channel after publishing" do
      publisher.publish(payload: { msg: "hi" }, queue_name: "test.queue")

      expect(mock_channel).to have_received(:close)
    end
  end

  describe "#with_channel" do
    it "closes the channel even when an error is raised during publishing" do
      allow(mock_exchange).to receive(:publish).and_raise(RuntimeError, "publish failed")

      expect {
        publisher.publish(payload: { msg: "hi" }, queue_name: "test.queue")
      }.to raise_error(RuntimeError, "publish failed")

      expect(mock_channel).to have_received(:close)
    end

    it "handles nil channel gracefully when create_channel raises before assignment" do
      allow(RabbitMq::Connection).to receive(:instance).and_return(
        instance_double(Bunny::Session).tap do |s|
          allow(s).to receive(:create_channel).and_raise(RuntimeError, "connection lost")
        end
      )

      expect {
        publisher.publish(payload: { msg: "hi" }, queue_name: "test.queue")
      }.to raise_error(RuntimeError, "connection lost")
    end
  end
end
