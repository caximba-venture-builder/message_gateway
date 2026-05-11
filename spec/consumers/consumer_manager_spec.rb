require "rails_helper"

RSpec.describe ConsumerManager do
  subject(:manager) { described_class.new }

  let(:mock_messages_consumer) do
    instance_double(MessagesConsumer, start: nil, cancel!: nil, in_flight_count: 0)
  end
  let(:mock_outgoing_consumer) do
    instance_double(OutgoingMessagesConsumer, start: nil, cancel!: nil, in_flight_count: 0)
  end

  def trigger_shutdown!
    manager.instance_variable_get(:@shutdown_queue) << "TEST"
  end

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
      trigger_shutdown!

      manager.start(incoming_queues: [ "bot.messages.upsert", "bot2.messages.upsert" ])

      expect(MessagesConsumer).to have_received(:new).with(queue_name: "bot.messages.upsert")
      expect(MessagesConsumer).to have_received(:new).with(queue_name: "bot2.messages.upsert")
      expect(mock_messages_consumer).to have_received(:start).twice
    end

    it "starts an OutgoingMessagesConsumer when outgoing_queue is given" do
      trigger_shutdown!

      manager.start(
        incoming_queues: [ "bot.messages.upsert" ],
        outgoing_queue: "bot.messages.outgoing"
      )

      expect(OutgoingMessagesConsumer).to have_received(:new).with(queue_name: "bot.messages.outgoing")
      expect(mock_outgoing_consumer).to have_received(:start)
    end

    it "does not start an OutgoingMessagesConsumer when outgoing_queue is nil" do
      trigger_shutdown!

      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(OutgoingMessagesConsumer).not_to have_received(:new)
    end

    it "blocks on the shutdown queue until a signal is enqueued" do
      thread = Thread.new { manager.start(incoming_queues: [ "bot.messages.upsert" ]) }

      sleep 0.05
      expect(thread).to be_alive

      trigger_shutdown!
      thread.join(2)
      expect(thread).not_to be_alive
    end

    it "traps INT and TERM signals" do
      trigger_shutdown!

      expect(Signal).to receive(:trap).with("INT")
      expect(Signal).to receive(:trap).with("TERM")

      manager.start(incoming_queues: [])
    end
  end

  describe "#stop" do
    it "cancels consumers before closing the RabbitMQ connection" do
      call_order = []
      allow(mock_messages_consumer).to receive(:cancel!) { call_order << :cancel }
      allow(RabbitMq::Connection).to receive(:close) { call_order << :close }

      trigger_shutdown!
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(call_order).to eq([ :cancel, :close ])
    end

    it "waits until in_flight_count drains to zero before closing the connection" do
      counts = [ 2, 2, 1, 0, 0 ]
      allow(mock_messages_consumer).to receive(:in_flight_count) { counts.shift || 0 }

      trigger_shutdown!
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(counts).to be_empty.or satisfy { |c| c.first == 0 }
      expect(mock_messages_consumer).to have_received(:cancel!)
      expect(RabbitMq::Connection).to have_received(:close)
    end

    it "logs a warning when drain times out" do
      stub_const("#{described_class}::SHUTDOWN_TIMEOUT", 0)
      allow(mock_messages_consumer).to receive(:in_flight_count).and_return(1)
      allow(Rails.logger).to receive(:warn)

      trigger_shutdown!
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(Rails.logger).to have_received(:warn).with(/Drain timeout/)
      expect(RabbitMq::Connection).to have_received(:close)
    end

    it "stops the heartbeat thread" do
      trigger_shutdown!
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      heartbeat = manager.instance_variable_get(:@heartbeat_thread)
      expect(heartbeat).not_to be_alive
    end
  end

  describe "heartbeat" do
    it "writes the heartbeat file while running" do
      thread = Thread.new { manager.start(incoming_queues: [ "bot.messages.upsert" ]) }

      sleep 0.1
      heartbeat_exists = File.exist?(ConsumerManager::HEARTBEAT_PATH)

      trigger_shutdown!
      thread.join(2)

      expect(heartbeat_exists).to be true
    end

    it "removes the heartbeat file on stop" do
      trigger_shutdown!
      manager.start(incoming_queues: [ "bot.messages.upsert" ])

      expect(File).not_to exist(ConsumerManager::HEARTBEAT_PATH)
    end
  end
end
