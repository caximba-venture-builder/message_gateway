class AudioTranscriptionJob < ApplicationJob
  queue_as :default
  retry_on AudioTranscriptionService::TranscriptionError, wait: :polynomially_longer, attempts: 3

  def perform(sender_id:, instance_name:, audio_url:, audio_mimetype:, whatsapp_message_id:)
    sender = Sender.find(sender_id)

    result = AudioTranscriptionService.call(
      audio_url: audio_url,
      mimetype: audio_mimetype
    )

    message = Message.find_by(whatsapp_message_id: whatsapp_message_id)
    if message
      TokenUsage.create!(
        sender: sender,
        message: message,
        tokens_used: result[:tokens_used],
        transcription_model: result[:model]
      )
    end

    ProcessedMessagePublisher.publish(
      sender: sender,
      text: result[:text]
    )
  end
end
