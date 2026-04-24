class ApplicationPublisher
  def self.publish(...)
    new.publish(...)
  end

  private

  def with_channel
    channel = RabbitMq::Connection.instance.create_channel
    yield channel
  ensure
    channel&.close
  end

  def publish_to_queue(channel, queue_name, payload, headers: nil)
    opts = {
      routing_key: queue_name,
      persistent: true,
      content_type: "application/json"
    }
    opts[:headers] = headers if headers

    channel.default_exchange.publish(
      payload.is_a?(String) ? payload : payload.to_json,
      **opts
    )
    Rails.logger.info("[#{self.class.name}] Published to #{queue_name}")
  end
end
