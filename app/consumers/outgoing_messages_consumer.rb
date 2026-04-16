class OutgoingMessagesConsumer < ApplicationConsumer
  private

  def handle_message(body, _properties)
    parsed = OutgoingMessageParser.call(body)

    Rails.logger.info("[OutgoingMessagesConsumer] Processing outgoing message from #{@queue_name}")

    OutgoingMessageSenderService.call(
      instance_name: @instance_name,
      phone_number: parsed[:phone_number],
      text: parsed[:text]
    )
  end
end
