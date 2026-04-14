require "rails_helper"

RSpec.describe ProcessedMessagePublisher do
  let(:sender) { create(:sender, phone_number: "5511999999999", push_name: "João") }
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
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("PROCESSED_MESSAGES_QUEUE").and_return("test.processed")
    end

    it "publishes to the PROCESSED_MESSAGES_QUEUE" do
      publisher.publish(sender: sender, text: "Hello world")

      expect(mock_channel).to have_received(:queue).with("test.processed", durable: true)
    end

    it "publishes the correct payload format" do
      publisher.publish(sender: sender, text: "Hello world")

      expected_payload = {
        id: sender.id,
        phone_number: "5511999999999",
        text: "Hello world",
        name: "João"
      }.to_json

      expect(mock_queue).to have_received(:publish).with(
        expected_payload,
        persistent: true,
        content_type: "application/json"
      )
    end
  end
end
