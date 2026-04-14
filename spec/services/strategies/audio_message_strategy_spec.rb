require "rails_helper"

RSpec.describe Strategies::AudioMessageStrategy do
  let(:sender) { create(:sender) }
  let(:payload) { build_audio_message_payload }
  let(:parsed_message) { MessageParser.call(payload) }

  describe "#call" do
    it "enqueues an AudioTranscriptionJob" do
      expect {
        described_class.new(parsed_message, sender).call
      }.to have_enqueued_job(AudioTranscriptionJob).with(
        sender_id: sender.id,
        instance_name: "materny-bot-ai",
        audio_url: "https://mmg.whatsapp.net/v/t62.7114-24/audio.ogg",
        audio_mimetype: "audio/ogg; codecs=opus",
        whatsapp_message_id: "3EB0B1C2D3E4F5A6B7C8D9"
      )
    end
  end
end
