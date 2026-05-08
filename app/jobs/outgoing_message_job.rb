class OutgoingMessageJob < ApplicationJob
  queue_as :default

  retry_on EvolutionApiClient::ApiError, wait: :polynomially_longer, attempts: 3

  def perform(instance_name:, phone_number:, text:)
    OutgoingMessageSenderService.call(
      instance_name: instance_name,
      phone_number: phone_number,
      text: text
    )
  end
end
