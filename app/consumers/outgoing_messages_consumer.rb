class OutgoingMessagesConsumer < ApplicationConsumer
  private

  def handle_message(body, _properties)
    payload = JSON.parse(body)

    Rails.logger.info("[OutgoingMessagesConsumer] Processing outgoing message from #{@queue_name}")

    OutgoingMessageSenderService.call(
      instance_name: @instance_name,
      phone_number: payload.fetch("phone_number"),
      text: payload.fetch("text")
    )
  end
end
