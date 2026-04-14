require "rails_helper"

RSpec.describe ProcessedMessagePublisher do
  let(:sender) { create(:sender, phone_number: "5511999999999", push_name: "João") }
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
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("PROCESSED_MESSAGES_QUEUE").and_return("test.processed")
    end

    it "publishes to the PROCESSED_MESSAGES_QUEUE" do
      publisher.publish(sender: sender, text: "Hello world")

      expect(mock_exchange).to have_received(:publish).with(
        anything,
        hash_including(routing_key: "test.processed")
      )
    end

    it "publishes the correct payload format" do
      publisher.publish(sender: sender, text: "Hello world")

      expected_payload = {
        id: sender.id,
        phone_number: "5511999999999",
        text: "Hello world",
        name: "João"
      }.to_json

      expect(mock_exchange).to have_received(:publish).with(
        expected_payload,
        routing_key: "test.processed",
        persistent: true,
        content_type: "application/json"
      )
    end
  end
end
