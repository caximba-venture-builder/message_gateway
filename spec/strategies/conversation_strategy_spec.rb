require "rails_helper"

RSpec.describe ConversationStrategy do
  let(:sender) { create(:sender) }
  let(:payload) { build_text_message_payload }
  let(:parsed_message) { MessageParser.call(payload) }

  describe "#call" do
    it "delegates to MessageConcatenationService" do
      expect(MessageConcatenationService).to receive(:call).with(
        sender: sender,
        instance_name: "materny-bot-ai",
        text: "Olá, tudo bem?"
      )

      described_class.new(parsed_message, sender).call
    end
  end
end
