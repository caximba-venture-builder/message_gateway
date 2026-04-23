require "rails_helper"

RSpec.describe ConsumerManager do
  subject(:manager) { described_class.new }

  let(:mock_messages_consumer) { instance_double(MessagesConsumer, start: nil) }
  let(:mock_outgoing_consumer) { instance_double(OutgoingMessagesConsumer, start: nil) }

  before do
    allow(MessagesConsumer).to receive(:new).and_return(mock_messages_consumer)
    allow(OutgoingMessagesConsumer).to receive(:new).and_return(mock_outgoing_consumer)
    allow(RabbitMq::Connection).to receive(:close)
    FileUtils.rm_f(ConsumerManager::HEARTBEAT_PATH)
  end

  after do
    FileUtils.rm_f(ConsumerManager::HEARTBEAT_PATH)
  end

  describe "#start" do
    it "starts a MessagesConsumer for each incoming queue" do
      allow(manager).to receive(:sleep) { manager.stop }

      manager.start(incoming_queues: [ "bot.messages.upsert", "bot2.messages.upsert" ])

      expect(MessagesConsumer).to have_received(:new).with(queue_name: "bot.messages.upsert")
      expect(MessagesConsumer).to have_received(:new).with(queue_name: "bot2.messages.upsert")
      expect(mock_messages_consumer).to have_received(:start).twice
    end

    it "starts an OutgoingMessagesConsumer when outgoing_queue is given" do
      allow(manager).to receive(:sleep) { manager.stop }

      manager.start(
        incoming_queues: [ "bot.messages.upsert" ],
        outgoing_queue: "bot.messages.outgoing"
      )

      expect(OutgoingMessagesConsumer).to have_received(:new).with(queue_name: "bot.messages.outgoing")
      expect(mock_outgoing_consumer).to have_received(:start)
    end

    it "does not start an OutgoingMessagesConsumer when outgoing_queue is nil" do
      allow(manager).to receive(:sleep) { manager.stop }

      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(OutgoingMessagesConsumer).not_to have_received(:new)
    end

    it "stops when @running is set to false" do
      call_count = 0
      allow(manager).to receive(:sleep) do
        call_count += 1
        manager.stop if call_count == 1
      end

      expect {
        manager.start(incoming_queues: [ "bot.messages.upsert" ])
      }.not_to raise_error
    end

    it "traps INT and TERM signals" do
      allow(manager).to receive(:sleep) { manager.stop }

      expect(Signal).to receive(:trap).with("INT")
      expect(Signal).to receive(:trap).with("TERM")

      manager.start(incoming_queues: [])
    end
  end

  describe "#stop" do
    it "closes the RabbitMQ connection" do
      manager.stop

      expect(RabbitMq::Connection).to have_received(:close)
    end
  end

  describe "heartbeat" do
    it "writes the heartbeat file while running" do
      heartbeat_exists = false
      allow(manager).to receive(:sleep) do
        sleep 0.05
        heartbeat_exists = File.exist?(ConsumerManager::HEARTBEAT_PATH)
        manager.stop
      end

      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(heartbeat_exists).to be true
    end

    it "removes the heartbeat file on stop" do
      allow(manager).to receive(:sleep) do
        sleep 0.05
        manager.stop
      end
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(File).not_to exist(ConsumerManager::HEARTBEAT_PATH)
    end
  end
end
