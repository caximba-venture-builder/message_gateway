require "rails_helper"
require "benchmark"

RSpec.describe OutgoingMessagesConsumer do
  let(:queue_name) { "materny-bot-ai.messages.outgoing" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  describe "#handle_message" do
    let(:payload) do
      { "id" => "sender-uuid", "phone_number" => "5511999999999", "text" => "Olá!", "name" => "João" }
    end
    let(:body) { payload.to_json }

    it "enqueues OutgoingMessageJob with instance_name derived from the queue" do
      expect {
        consumer.send(:handle_message, body, double(headers: nil))
      }.to have_enqueued_job(OutgoingMessageJob).with(
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

    it "ACKs 10 messages of 200 chars in under 1s" do
      body = { "phone_number" => "5511999999999", "text" => "x" * 200 }.to_json
      properties = double(headers: nil)

      elapsed = Benchmark.realtime do
        10.times { consumer.send(:handle_message, body, properties) }
      end

      expect(elapsed).to be < 1.0
      expect(OutgoingMessageJob).to have_been_enqueued.exactly(10).times
    end
  end
end
