module Strategies
  class AudioMessageStrategy < BaseStrategy
    def call
      AudioTranscriptionJob.perform_later(
        sender_id: @sender.id,
        media_url: @parsed_message.media_url,
        audio_mimetype: @parsed_message.audio_mimetype,
        whatsapp_message_id: @parsed_message.whatsapp_message_id
      )
    end
  end
end
