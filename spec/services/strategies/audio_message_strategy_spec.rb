require "rails_helper"

RSpec.describe Strategies::AudioMessageStrategy do
  let(:sender) { create(:sender) }
  let(:payload) { build_audio_message_payload }
  let(:parsed_message) { MessageParser.call(payload) }

  describe "#call" do
    it "enqueues an AudioTranscriptionJob with Evolution API params" do
      expect {
        described_class.new(parsed_message, sender).call
      }.to have_enqueued_job(AudioTranscriptionJob).with(
        sender_id: sender.id,
        instance_name: "materny-bot-ai",
        server_url: "https://your-evolution-api.com",
        api_key: "your-api-key",
        audio_message: hash_including("audioMessage" => hash_including("mimetype" => "audio/ogg; codecs=opus")),
        audio_mimetype: "audio/ogg; codecs=opus",
        whatsapp_message_id: "3EB0B1C2D3E4F5A6B7C8D9"
      )
    end
  end
end
