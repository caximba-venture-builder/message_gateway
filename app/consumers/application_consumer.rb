class ApplicationConsumer
  MAX_RETRIES = ENV.fetch("MESSAGE_MAX_RETRY_COUNT", 3).to_i

  def initialize(queue_name:)
    @queue_name = queue_name
    @instance_name = InstanceNameValidator.call!(queue_name.split(".").first)
  end

  def start
    channel = RabbitMq::Connection.instance.create_channel
    channel.prefetch(1)

    queue = channel.queue(@queue_name, durable: true, arguments: { "x-queue-type" => "quorum" })

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
    DeadLetterPublisher.publish(
      source_queue: @queue_name,
      body: body,
      retry_count: 0,
      error_message: e.message
    )
    channel.ack(delivery_info.delivery_tag)
  rescue StandardError => e
    handle_failure(channel, delivery_info, properties, body, e)
  end

  def handle_message(_body, _properties)
    raise NotImplementedError, "Subclasses must implement #handle_message"
  end

  def handle_failure(channel, delivery_info, properties, body, error)
    retry_count = extract_retry_count(properties)

    if retry_count < MAX_RETRIES
      Rails.logger.warn("[#{self.class.name}] Retry #{retry_count + 1}/#{MAX_RETRIES}: #{error.message}")
      channel.ack(delivery_info.delivery_tag)
      republish_with_retry(body, retry_count + 1)
    else
      Rails.logger.error("[#{self.class.name}] Max retries reached. Sending to DLQ: #{error.message}")
      DeadLetterPublisher.publish(
        source_queue: @queue_name,
        body: body,
        retry_count: retry_count,
        error_message: error.message
      )
      channel.ack(delivery_info.delivery_tag)
    end
  end

  def extract_retry_count(properties)
    headers = properties.headers || {}
    headers["x-retry-count"].to_i
  end

  def republish_with_retry(body, retry_count)
    channel = RabbitMq::Connection.instance.create_channel
    queue = channel.queue(@queue_name, durable: true, arguments: { "x-queue-type" => "quorum" })
    queue.publish(
      body,
      persistent: true,
      content_type: "application/json",
      headers: { "x-retry-count" => retry_count }
    )
  ensure
    channel&.close
  end
end
