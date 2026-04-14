require "rails_helper"

RSpec.describe AudioTranscriptionJob, type: :job do
  let(:sender) { create(:sender) }
  let(:message) { create(:message, :audio, sender: sender, whatsapp_message_id: "3EB0TEST123") }
  let(:mock_channel) { instance_double(Bunny::Channel, close: nil) }
  let(:mock_exchange) { instance_double(Bunny::Exchange) }

  before do
    message # ensure message exists before job runs

    allow(RabbitMq::Connection).to receive(:instance).and_return(
      instance_double(Bunny::Session, create_channel: mock_channel)
    )
    allow(mock_channel).to receive(:default_exchange).and_return(mock_exchange)
    allow(mock_exchange).to receive(:publish)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("PROCESSED_MESSAGES_QUEUE").and_return("test.processed")

    allow(AudioTranscriptionService).to receive(:call).and_return({
      text: "Transcribed audio text",
      tokens_used: 100,
      model: "whisper-1"
    })
  end

  describe "#perform" do
    it "calls AudioTranscriptionService" do
      described_class.new.perform(
        sender_id: sender.id,
        instance_name: "materny-bot-ai",
        audio_url: "https://example.com/audio.ogg",
        audio_mimetype: "audio/ogg",
        whatsapp_message_id: "3EB0TEST123"
      )

      expect(AudioTranscriptionService).to have_received(:call).with(
        audio_url: "https://example.com/audio.ogg",
        mimetype: "audio/ogg"
      )
    end

    it "creates a TokenUsage record" do
      expect {
        described_class.new.perform(
          sender_id: sender.id,
          instance_name: "materny-bot-ai",
          audio_url: "https://example.com/audio.ogg",
          audio_mimetype: "audio/ogg",
          whatsapp_message_id: "3EB0TEST123"
        )
      }.to change(TokenUsage, :count).by(1)

      token_usage = TokenUsage.last
      expect(token_usage.sender_id).to eq(sender.id)
      expect(token_usage.message_id).to eq(message.id)
      expect(token_usage.tokens_used).to eq(100)
      expect(token_usage.transcription_model).to eq("whisper-1")
    end

    it "publishes the transcribed text" do
      described_class.new.perform(
        sender_id: sender.id,
        instance_name: "materny-bot-ai",
        audio_url: "https://example.com/audio.ogg",
        audio_mimetype: "audio/ogg",
        whatsapp_message_id: "3EB0TEST123"
      )

      expect(mock_exchange).to have_received(:publish)
    end

    context "when message record does not exist yet" do
      it "still publishes but does not create token_usage" do
        expect {
          described_class.new.perform(
            sender_id: sender.id,
            instance_name: "materny-bot-ai",
            audio_url: "https://example.com/audio.ogg",
            audio_mimetype: "audio/ogg",
            whatsapp_message_id: "NONEXISTENT"
          )
        }.not_to change(TokenUsage, :count)

        expect(mock_exchange).to have_received(:publish)
      end
    end
  end
end
