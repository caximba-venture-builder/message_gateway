class ApplicationConsumer
  MAX_RETRIES = ENV.fetch("MESSAGE_MAX_RETRY_COUNT", 3).to_i
  RETRY_COUNT_HEADER = "x-retry-count".freeze
  QUEUE_ARGUMENTS = { "x-queue-type" => "quorum" }.freeze

  def initialize(queue_name:)
    @queue_name = queue_name
    @instance_name = InstanceNameValidator.call!(queue_name.split(".").first)
  end

  def start
    channel = RabbitMq::Connection.instance.create_channel
    channel.prefetch(1)

    queue = channel.queue(@queue_name, durable: true, arguments: QUEUE_ARGUMENTS)

    Rails.logger.info("[#{self.class.name}] Subscribed to #{@queue_name}")

    queue.subscribe(manual_ack: true, block: false) do |delivery_info, properties, body|
      process_delivery(channel, delivery_info, properties, body)
    end
  end

  private

  def process_delivery(channel, delivery_info, properties, body)
    handle_message(body, properties)
    channel.ack(delivery_info.delivery_tag)
  rescue JSON::ParserError => e
    Rails.logger.error("[#{self.class.name}] Invalid JSON: #{e.message}")
    ack_after_publish(channel, delivery_info) do
      DeadLetterPublisher.publish(
        source_queue: @queue_name,
        body: body,
        retry_count: 0,
        error_message: e.message
      )
    end
  rescue StandardError => e
    handle_failure(channel, delivery_info, properties, body, e)
  end

  def handle_message(_body, _properties)
    raise NotImplementedError, "Subclasses must implement #handle_message"
  end

  def handle_failure(channel, delivery_info, properties, body, error)
    retry_count = extract_retry_count(properties)

    ack_after_publish(channel, delivery_info) do
      if retry_count < MAX_RETRIES
        Rails.logger.warn("[#{self.class.name}] Retry #{retry_count + 1}/#{MAX_RETRIES}: #{error.message}")
        RetryPublisher.publish(queue_name: @queue_name, body: body, retry_count: retry_count + 1)
      else
        Rails.logger.error("[#{self.class.name}] Max retries reached. Sending to DLQ: #{error.message}")
        DeadLetterPublisher.publish(
          source_queue: @queue_name,
          body: body,
          retry_count: retry_count,
          error_message: error.message
        )
      end
    end
  end

  def ack_after_publish(channel, delivery_info)
    yield
    channel.ack(delivery_info.delivery_tag)
  rescue StandardError => publish_error
    Rails.logger.error(
      "[#{self.class.name}] Publish failed (#{publish_error.class}: #{publish_error.message}); " \
      "nacking for redelivery"
    )
    channel.nack(delivery_info.delivery_tag, false, true)
  end

  def extract_retry_count(properties)
    headers = properties.headers || {}
    headers[RETRY_COUNT_HEADER].to_i
  end
end
