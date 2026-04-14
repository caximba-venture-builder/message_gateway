module Strategies
  class AudioMessageStrategy < BaseStrategy
    def call
      AudioTranscriptionJob.perform_later(
        sender_id: @sender.id,
        instance_name: @parsed_message.instance_name,
        server_url: @parsed_message.server_url,
        api_key: @parsed_message.api_key,
        audio_message: @parsed_message.audio_message,
        audio_mimetype: @parsed_message.audio_mimetype,
        whatsapp_message_id: @parsed_message.whatsapp_message_id
      )
    end
  end
end
