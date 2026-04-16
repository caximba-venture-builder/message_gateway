class ConsumerManager
  def initialize
    @consumers = []
    @running = false
  end

  def start(incoming_queues:, outgoing_queue: nil)
    @running = true
    setup_signal_handlers

    incoming_queues.each { |name| start_consumer(MessagesConsumer, name) }
    start_consumer(OutgoingMessagesConsumer, outgoing_queue) if outgoing_queue

    Rails.logger.info("[ConsumerManager] All consumers started. Waiting for messages...")

    sleep(1) while @running
  end

  def stop
    Rails.logger.info("[ConsumerManager] Shutting down...")
    @running = false
    RabbitMq::Connection.close
    Rails.logger.info("[ConsumerManager] All consumers stopped.")
  end

  private

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
