class ConsumerManager
  def initialize
    @consumers = []
    @running = false
  end

  def start(queue_names)
    @running = true
    setup_signal_handlers

    queue_names.each do |queue_name|
      consumer = MessagesConsumer.new(queue_name: queue_name)
      consumer.start
      @consumers << consumer
    end

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

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) { stop }
    end
  end
end
