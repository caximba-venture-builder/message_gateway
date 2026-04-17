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

    allow(AudioDownloader).to receive(:call).and_return({
      binary: "fake audio binary".b
    })

    allow(AudioTranscriptionService).to receive(:call).and_return({
      text: "Transcribed audio text",
      tokens_used: 100,
      model: "whisper-1"
    })
  end

  describe "#perform" do
    let(:job_args) do
      {
        sender_id: sender.id,
        media_url: "https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123",
        audio_mimetype: "audio/ogg; codecs=opus",
        whatsapp_message_id: "3EB0TEST123"
      }
    end

    it "downloads audio from media_url" do
      described_class.new.perform(**job_args)

      expect(AudioDownloader).to have_received(:call).with(
        url: "https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123"
      )
    end

    it "calls AudioTranscriptionService with downloaded binary and normalized mimetype" do
      described_class.new.perform(**job_args)

      expect(AudioTranscriptionService).to have_received(:call).with(
        binary: "fake audio binary".b,
        mimetype: "audio/ogg"
      )
    end

    it "creates a TokenUsage record" do
      expect {
        described_class.new.perform(**job_args)
      }.to change(TokenUsage, :count).by(1)

      token_usage = TokenUsage.last
      expect(token_usage.sender_id).to eq(sender.id)
      expect(token_usage.message_id).to eq(message.id)
      expect(token_usage.tokens_used).to eq(100)
      expect(token_usage.transcription_model).to eq("whisper-1")
    end

    it "publishes the transcribed text" do
      described_class.new.perform(**job_args)

      expect(mock_exchange).to have_received(:publish)
    end

    context "when message record does not exist yet" do
      it "still publishes but does not create token_usage" do
        expect {
          described_class.new.perform(**job_args.merge(whatsapp_message_id: "NONEXISTENT"))
        }.not_to change(TokenUsage, :count)

        expect(mock_exchange).to have_received(:publish)
      end
    end

    context "when audio_mimetype is not in the allowlist" do
      before { allow(Rails.logger).to receive(:error) }

      it "discards the job without calling downloader or service" do
        expect {
          described_class.perform_now(**job_args.merge(audio_mimetype: "application/json"))
        }.not_to raise_error

        expect(AudioDownloader).not_to have_received(:call)
        expect(AudioTranscriptionService).not_to have_received(:call)
      end

      it "logs the discard reason" do
        described_class.perform_now(**job_args.merge(audio_mimetype: "application/json"))

        expect(Rails.logger).to have_received(:error).with(/invalid audio mimetype/)
      end
    end

    context "when AudioTranscriptionService raises InvalidAudioError" do
      before do
        allow(AudioTranscriptionService).to receive(:call)
          .and_raise(AudioTranscriptionService::InvalidAudioError, "OpenAI rejected the audio (400): bad format")
        allow(Rails.logger).to receive(:error)
      end

      it "discards the job without raising" do
        expect {
          described_class.perform_now(**job_args)
        }.not_to raise_error
      end

      it "logs the discard reason" do
        described_class.perform_now(**job_args)

        expect(Rails.logger).to have_received(:error).with(/Discarding job.*bad format/)
      end
    end
  end
end
