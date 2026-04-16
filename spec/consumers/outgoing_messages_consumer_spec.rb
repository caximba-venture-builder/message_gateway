require "rails_helper"

RSpec.describe OutgoingMessagesConsumer do
  let(:queue_name) { "materny-bot-ai.messages.outgoing" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  before do
    allow(OutgoingMessageSenderService).to receive(:call)
  end

  describe "#handle_message" do
    let(:payload) do
      { "id" => "sender-uuid", "phone_number" => "5511999999999", "text" => "Olá!", "name" => "João" }
    end
    let(:body) { payload.to_json }

    it "calls OutgoingMessageSenderService with instance_name derived from the queue" do
      consumer.send(:handle_message, body, double(headers: nil))

      expect(OutgoingMessageSenderService).to have_received(:call).with(
        instance_name: "materny-bot-ai",
        phone_number: "5511999999999",
        text: "Olá!"
      )
    end

    it "raises OutgoingMessageParser::ParseError when the payload is missing required fields" do
      bad_body = { "foo" => "bar" }.to_json
      expect {
        consumer.send(:handle_message, bad_body, double(headers: nil))
      }.to raise_error(OutgoingMessageParser::ParseError)
    end
  end
end
