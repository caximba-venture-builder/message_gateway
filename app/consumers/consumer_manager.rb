class ConsumerManager
  HEARTBEAT_INTERVAL = 5
  HEARTBEAT_PATH = Rails.root.join("tmp/heartbeat/consumer")

  def initialize
    @consumers = []
    @running = false
    @heartbeat_thread = nil
  end

  def start(incoming_queues:, outgoing_queue: nil)
    @running = true
    setup_signal_handlers
    start_heartbeat

    incoming_queues.each { |name| start_consumer(MessagesConsumer, name) }
    start_consumer(OutgoingMessagesConsumer, outgoing_queue) if outgoing_queue

    Rails.logger.info("[ConsumerManager] All consumers started. Waiting for messages...")

    sleep(1) while @running
  end

  def stop
    Rails.logger.info("[ConsumerManager] Shutting down...")
    @running = false
    @heartbeat_thread&.kill
    FileUtils.rm_f(HEARTBEAT_PATH)
    RabbitMq::Connection.close
    Rails.logger.info("[ConsumerManager] All consumers stopped.")
  end

  private

  def start_heartbeat
    FileUtils.mkdir_p(HEARTBEAT_PATH.dirname)
    @heartbeat_thread = Thread.new do
      while @running
        FileUtils.touch(HEARTBEAT_PATH)
        sleep HEARTBEAT_INTERVAL
      end
    end
  end

  def start_consumer(consumer_class, queue_name)
    consumer = consumer_class.new(queue_name: queue_name)
    consumer.start
    @consumers << consumer
  end

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) { stop }
    end
  end
end
