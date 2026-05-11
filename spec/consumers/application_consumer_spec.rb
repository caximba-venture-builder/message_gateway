require "rails_helper"

RSpec.describe ApplicationConsumer do
  let(:queue_name) { "test-bot.messages.upsert" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  describe ".new" do
    it "rejects queue names whose prefix fails instance name validation" do
      expect {
        described_class.new(queue_name: "../../evil.messages")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end

    it "rejects uppercase instance prefixes" do
      expect {
        described_class.new(queue_name: "EvilBot.messages")
      }.to raise_error(InstanceNameValidator::InvalidInstanceNameError)
    end
  end

  describe "#start" do
    let(:mock_channel) { instance_double(Bunny::Channel) }
    let(:mock_queue) { instance_double(Bunny::Queue) }
    let(:mock_bunny_consumer) { instance_double(Bunny::Consumer) }
    let(:mock_connection) { instance_double(Bunny::Session, create_channel: mock_channel) }

    before do
      allow(RabbitMq::Connection).to receive(:instance).and_return(mock_connection)
      allow(mock_channel).to receive(:prefetch)
      allow(mock_channel).to receive(:queue).and_return(mock_queue)
      allow(mock_queue).to receive(:subscribe).and_return(mock_bunny_consumer)
    end

    it "creates a channel and subscribes to the queue" do
      consumer.start

      expect(mock_channel).to have_received(:prefetch).with(1)
      expect(mock_channel).to have_received(:queue).with(
        queue_name,
        durable: true,
        arguments: { "x-queue-type" => "quorum" }
      )
      expect(mock_queue).to have_received(:subscribe).with(manual_ack: true, block: false)
    end
  end

  describe "#cancel!" do
    let(:mock_channel) { instance_double(Bunny::Channel, prefetch: nil) }
    let(:mock_queue) { instance_double(Bunny::Queue) }
    let(:mock_bunny_consumer) { instance_double(Bunny::Consumer, cancel: nil) }
    let(:mock_connection) { instance_double(Bunny::Session, create_channel: mock_channel) }

    before do
      allow(RabbitMq::Connection).to receive(:instance).and_return(mock_connection)
      allow(mock_channel).to receive(:queue).and_return(mock_queue)
      allow(mock_queue).to receive(:subscribe).and_return(mock_bunny_consumer)
    end

    it "cancels the bunny consumer" do
      consumer.start
      consumer.cancel!

      expect(mock_bunny_consumer).to have_received(:cancel)
    end

    it "is a no-op when start was never called" do
      expect { consumer.cancel! }.not_to raise_error
    end
  end

  describe "#in_flight_count" do
    let(:mock_channel) { instance_double(Bunny::Channel, prefetch: nil) }
    let(:mock_queue) { instance_double(Bunny::Queue) }
    let(:mock_bunny_consumer) { instance_double(Bunny::Consumer) }
    let(:mock_connection) { instance_double(Bunny::Session, create_channel: mock_channel) }
    let(:captured_block) { [] }

    before do
      allow(RabbitMq::Connection).to receive(:instance).and_return(mock_connection)
      allow(mock_channel).to receive(:queue).and_return(mock_queue)
      allow(mock_channel).to receive(:ack)
      allow(mock_queue).to receive(:subscribe) do |&block|
        captured_block << block
        mock_bunny_consumer
      end
      allow(consumer).to receive(:handle_message)
    end

    it "starts at zero" do
      expect(consumer.in_flight_count).to eq(0)
    end

    it "increments during processing and decrements after" do
      observed = nil
      allow(consumer).to receive(:handle_message) { observed = consumer.in_flight_count }

      consumer.start
      delivery_info = double(delivery_tag: "tag-1")
      properties = double(headers: nil)
      captured_block.first.call(delivery_info, properties, "{}")

      expect(observed).to eq(1)
      expect(consumer.in_flight_count).to eq(0)
    end

    it "decrements even when the handler raises" do
      allow(consumer).to receive(:handle_message).and_raise(StandardError, "boom")
      allow(consumer).to receive(:handle_failure)

      consumer.start
      delivery_info = double(delivery_tag: "tag-1")
      properties = double(headers: nil)
      captured_block.first.call(delivery_info, properties, "{}")

      expect(consumer.in_flight_count).to eq(0)
    end
  end

  describe "#extract_retry_count" do
    it "returns 0 when no headers" do
      properties = double(headers: nil)
      expect(consumer.send(:extract_retry_count, properties)).to eq(0)
    end

    it "returns 0 when no x-retry-count header" do
      properties = double(headers: {})
      expect(consumer.send(:extract_retry_count, properties)).to eq(0)
    end

    it "returns the retry count from headers" do
      properties = double(headers: { "x-retry-count" => 2 })
      expect(consumer.send(:extract_retry_count, properties)).to eq(2)
    end
  end

  describe "#handle_message" do
    it "raises NotImplementedError" do
      expect {
        consumer.send(:handle_message, "{}", double(headers: nil))
      }.to raise_error(NotImplementedError)
    end
  end
end
