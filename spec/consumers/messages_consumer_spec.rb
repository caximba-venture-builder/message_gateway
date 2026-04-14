require "rails_helper"

RSpec.describe MessagesConsumer do
  let(:queue_name) { "materny-bot-ai.messages.upsert" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  describe "#handle_message (via process_delivery)" do
    let(:payload) { build_text_message_payload }
    let(:body) { payload.to_json }

    it "enqueues an IncomingMessageJob" do
      expect {
        consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(IncomingMessageJob).with(
        payload: payload,
        instance_name: "materny-bot-ai"
      )
    end

    it "extracts instance_name from queue_name" do
      custom_consumer = described_class.new(queue_name: "my-bot.messages.upsert")

      expect {
        custom_consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(IncomingMessageJob).with(
        payload: payload,
        instance_name: "my-bot"
      )
    end
  end
end
