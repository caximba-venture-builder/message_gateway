class OutgoingMessagesConsumer < ApplicationConsumer
  private

  def handle_message(body, _properties)
    parsed = OutgoingMessageParser.call(body)

    Rails.logger.info("[OutgoingMessagesConsumer] Enqueuing outgoing message from #{@queue_name}")

    OutgoingMessageJob.perform_later(
      instance_name: @instance_name,
      phone_number: parsed[:phone_number],
      text: parsed[:text]
    )
  end
end
