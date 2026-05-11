class AudioTranscriptionJob < ApplicationJob
  queue_as :default
  retry_on AudioTranscriptionService::TranscriptionError, wait: :polynomially_longer, attempts: 3
  retry_on AudioDownloader::DownloadError, wait: :polynomially_longer, attempts: 3
  discard_on AudioDownloader::OversizeAudioError do |job, error|
    sender_id = job.arguments.first&.dig(:sender_id)
    whatsapp_message_id = job.arguments.first&.dig(:whatsapp_message_id)
    Rails.logger.warn(
      "[AudioTranscriptionJob] event=audio_oversize sender_id=#{sender_id} " \
      "whatsapp_message_id=#{whatsapp_message_id} limit=#{AudioTranscriptionService::MAX_AUDIO_BYTES} " \
      "error=#{error.message}"
    )
  end
  discard_on AudioTranscriptionService::InvalidAudioError do |job, error|
    Rails.logger.error("[AudioTranscriptionJob] Discarding job — audio rejected by OpenAI: #{error.message}")
  end
  discard_on MimetypeValidator::InvalidMimetypeError do |job, error|
    Rails.logger.error("[AudioTranscriptionJob] Discarding job — invalid audio mimetype: #{error.message}")
  end
  discard_on ActiveRecord::RecordNotFound

  def perform(sender_id:, media_url:, audio_mimetype:, whatsapp_message_id:)
    sender = Sender.find(sender_id)

    validated_mimetype = MimetypeValidator.call!(audio_mimetype)
    downloaded = AudioDownloader.call(url: media_url)

    result = AudioTranscriptionService.call(
      binary: downloaded[:binary],
      mimetype: validated_mimetype
    )

    message = Message.find_by(whatsapp_message_id: whatsapp_message_id)
    if message.nil?
      Rails.logger.warn("[AudioTranscriptionJob] Message not found sender_id=#{sender_id} whatsapp_message_id=#{whatsapp_message_id}")
      return
    end

    TokenUsage.create!(
      sender: sender,
      message: message,
      tokens_used: result[:tokens_used],
      transcription_model: result[:model]
    )

    ProcessedMessagePublisher.publish(
      sender: sender,
      text: result[:text]
    )
  end
end
