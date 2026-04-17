class ProcessedMessagePublisher < ApplicationPublisher
  def publish(sender:, text:)
    enveloped = if LlmEnvelope.enabled?
      LlmEnvelope.wrap(text: text, name: sender.push_name)
    else
      { text: text, name: sender.push_name }
    end

    payload = {
      id: sender.id,
      phone_number: sender.phone_number,
      text: enveloped[:text],
      name: enveloped[:name]
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
