module RabbitMq
  class Connection
    class << self
      def instance
        @mutex ||= Mutex.new
        @mutex.synchronize do
          if @connection.nil? || !@connection.open?
            @connection = Bunny.new(
              ENV.fetch("RABBITMQ_URL", "amqp://guest:guest@localhost:5672"),
              automatically_recover: true,
              network_recovery_interval: 5.0,
              recovery_attempts: 10,
              continuation_timeout: 15_000,
              heartbeat: 30
            )
            @connection.start
            Rails.logger.info("[RabbitMQ] Connection established to #{@connection.host}")
          end
          @connection
        end
      end

      def close
        @mutex&.synchronize do
          @connection&.close if @connection&.open?
          @connection = nil
        end
      end

      def reset!
        @mutex&.synchronize { @connection = nil }
      end
    end
  end
end
