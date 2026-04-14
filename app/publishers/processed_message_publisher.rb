class ProcessedMessagePublisher < ApplicationPublisher
  def publish(sender:, text:)
    payload = {
      id: sender.id,
      phone_number: sender.phone_number,
      text: text,
      name: sender.push_name
    }

    with_channel do |channel|
      publish_to_queue(channel, queue_name, payload)
    end
  end

  private

  def queue_name
    ENV.fetch("PROCESSED_MESSAGES_QUEUE")
  end
end
