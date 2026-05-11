class ConsumerManager
  HEARTBEAT_INTERVAL = 5
  HEARTBEAT_PATH = Rails.root.join("tmp/heartbeat/consumer")
  SHUTDOWN_TIMEOUT = ENV.fetch("CONSUMER_SHUTDOWN_TIMEOUT", 30).to_i

  def initialize
    @consumers = []
    @heartbeat_thread = nil
    @heartbeat_running = false
    @shutdown_queue = Queue.new
  end

  def start(incoming_queues:, outgoing_queue: nil)
    setup_signal_handlers
    start_heartbeat

    incoming_queues.each { |name| start_consumer(MessagesConsumer, name) }
    start_consumer(OutgoingMessagesConsumer, outgoing_queue) if outgoing_queue

    Rails.logger.info("[ConsumerManager] All consumers started. Waiting for messages...")

    @shutdown_queue.pop
    stop
  end

  def stop
    Rails.logger.info("[ConsumerManager] Shutting down (timeout=#{SHUTDOWN_TIMEOUT}s)...")

    @consumers.each(&:cancel!)
    drained = await_drain(SHUTDOWN_TIMEOUT)
    Rails.logger.warn("[ConsumerManager] Drain timeout — in-flight will be redelivered") unless drained

    stop_heartbeat
    RabbitMq::Connection.close
    Rails.logger.info("[ConsumerManager] Stopped (drained=#{drained}).")
  end

  private

  def await_drain(timeout)
    deadline = Time.current + timeout
    until @consumers.sum(&:in_flight_count).zero?
      return false if Time.current >= deadline
      sleep 0.1
    end
    true
  end

  def stop_heartbeat
    @heartbeat_running = false
    @heartbeat_thread&.wakeup if @heartbeat_thread&.alive?
    @heartbeat_thread&.join(HEARTBEAT_INTERVAL + 1)
    FileUtils.rm_f(HEARTBEAT_PATH)
  end

  def start_heartbeat
    FileUtils.mkdir_p(HEARTBEAT_PATH.dirname)
    @heartbeat_running = true
    @heartbeat_thread = Thread.new do
      while @heartbeat_running
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
      Signal.trap(signal) { @shutdown_queue << signal }
    end
  end
end
