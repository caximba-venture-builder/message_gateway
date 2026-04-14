module Strategies
  class AudioMessageStrategy < BaseStrategy
    def call
      AudioTranscriptionJob.perform_later(
        sender_id: @sender.id,
        instance_name: @parsed_message.instance_name,
        audio_url: @parsed_message.audio_url,
        audio_mimetype: @parsed_message.audio_mimetype,
        whatsapp_message_id: @parsed_message.whatsapp_message_id
      )
    end
  end
end
