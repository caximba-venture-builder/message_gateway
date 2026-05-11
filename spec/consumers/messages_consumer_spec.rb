require "rails_helper"

RSpec.describe MessagesConsumer do
  let(:queue_name) { "materny-bot-ai.messages.upsert" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  describe "#handle_message (via process_delivery)" do
    let(:payload) { build_text_message_payload("apikey" => "super-secret-evolution-key") }
    let(:body) { payload.to_json }
    let(:sanitized_payload) { payload.except("apikey") }

    it "enqueues an IncomingMessageJob with the apikey stripped" do
      expect {
        consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(IncomingMessageJob).with(
        payload: sanitized_payload,
        instance_name: "materny-bot-ai"
      )
    end

    it "does not pass the apikey as a job argument" do
      expect {
        consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(IncomingMessageJob).with { |args|
        expect(args[:payload]).not_to have_key("apikey")
        expect(args[:payload].to_json).not_to include("super-secret-evolution-key")
      }
    end

    it "extracts instance_name from queue_name" do
      custom_consumer = described_class.new(queue_name: "my-bot.messages.upsert")

      expect {
        custom_consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(IncomingMessageJob).with(
        payload: sanitized_payload,
        instance_name: "my-bot"
      )
    end
  end
end
