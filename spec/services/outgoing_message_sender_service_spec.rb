require "rails_helper"

RSpec.describe OutgoingMessageSenderService do
  let(:client) { instance_double(EvolutionApiClient) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(EvolutionApiClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_presence)
    allow(client).to receive(:send_text)
  end

  describe ".call" do
    it "computes delay as 35ms per character by default and passes it to send_presence" do
      allow(ENV).to receive(:fetch).with("OUTGOING_TYPING_DELAY_MS_PER_CHAR", 35).and_return(35)
      allow_any_instance_of(described_class).to receive(:sleep)

      described_class.call(
        instance_name: "materny-bot-ai",
        phone_number: "5511999999999",
        text: "Olá!"
      )

      expect(client).to have_received(:send_presence).with(number: "5511999999999", delay_ms: 140)
      expect(client).to have_received(:send_text).with(number: "5511999999999", text: "Olá!")
    end

    it "sleeps 0.5 seconds between presence and text" do
      allow(ENV).to receive(:fetch).with("OUTGOING_TYPING_DELAY_MS_PER_CHAR", 35).and_return(35)

      expect_any_instance_of(described_class).to receive(:sleep).with(0.5)

      described_class.call(
        instance_name: "materny-bot-ai",
        phone_number: "5511999999999",
        text: "Olá!"
      )
    end

    it "honors OUTGOING_TYPING_DELAY_MS_PER_CHAR env var" do
      allow(ENV).to receive(:fetch).with("OUTGOING_TYPING_DELAY_MS_PER_CHAR", 35).and_return("10")
      allow_any_instance_of(described_class).to receive(:sleep)

      described_class.call(
        instance_name: "materny-bot-ai",
        phone_number: "5511999999999",
        text: "abcde"
      )

      expect(client).to have_received(:send_presence).with(number: "5511999999999", delay_ms: 50)
    end

    it "sends presence before sleeping and text after" do
      allow(ENV).to receive(:fetch).with("OUTGOING_TYPING_DELAY_MS_PER_CHAR", 35).and_return(35)
      sequence = []
      allow(client).to receive(:send_presence) { sequence << :presence }
      allow_any_instance_of(described_class).to receive(:sleep) { sequence << :sleep }
      allow(client).to receive(:send_text) { sequence << :text }

      described_class.call(
        instance_name: "materny-bot-ai",
        phone_number: "5511999999999",
        text: "hi"
      )

      expect(sequence).to eq(%i[presence sleep text])
    end
  end
end
