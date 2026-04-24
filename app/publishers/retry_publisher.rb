class RetryPublisher < ApplicationPublisher
  def publish(queue_name:, body:, retry_count:)
    with_channel do |channel|
      publish_to_queue(
        channel,
        queue_name,
        body,
        headers: { ApplicationConsumer::RETRY_COUNT_HEADER => retry_count }
      )
    end
  end
end
