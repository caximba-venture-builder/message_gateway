class MessagesConsumer < ApplicationConsumer
  private

  def handle_message(body, _properties)
    payload = JSON.parse(body)

    Rails.logger.info("[MessagesConsumer] Processing message from #{@queue_name}")

    IncomingMessageJob.perform_later(
      payload: payload,
      instance_name: @instance_name
    )
  end
end
