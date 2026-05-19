class OutgoingMessagesConsumer < ApplicationConsumer
  DLX_EXCHANGE = "dlx".freeze
  DELIVERY_LIMIT = 3

  private

  def queue_arguments
    ApplicationConsumer::QUEUE_ARGUMENTS.merge(
      "x-dead-letter-exchange" => DLX_EXCHANGE,
      "x-dead-letter-routing-key" => @queue_name,
      "x-delivery-limit" => DELIVERY_LIMIT
    )
  end

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
