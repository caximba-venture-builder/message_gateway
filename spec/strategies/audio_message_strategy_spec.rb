require "rails_helper"

RSpec.describe AudioMessageStrategy do
  let(:sender) { create(:sender) }
  let(:payload) { build_audio_message_payload }
  let(:parsed_message) { MessageParser.call(payload) }

  describe "#call" do
    it "enqueues an AudioTranscriptionJob with media_url params" do
      expect {
        described_class.new(parsed_message, sender).call
      }.to have_enqueued_job(AudioTranscriptionJob).with(
        sender_id: sender.id,
        media_url: "https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123",
        audio_mimetype: "audio/ogg; codecs=opus",
        whatsapp_message_id: "3EB0B1C2D3E4F5A6B7C8D9"
      )
    end
  end
end
