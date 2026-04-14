require "rails_helper"

RSpec.describe ApplicationConsumer do
  let(:queue_name) { "test-bot.messages.upsert" }
  let(:consumer) { described_class.new(queue_name: queue_name) }

  describe "#extract_retry_count" do
    it "returns 0 when no headers" do
      properties = double(headers: nil)
      expect(consumer.send(:extract_retry_count, properties)).to eq(0)
    end

    it "returns 0 when no x-retry-count header" do
      properties = double(headers: {})
      expect(consumer.send(:extract_retry_count, properties)).to eq(0)
    end

    it "returns the retry count from headers" do
      properties = double(headers: { "x-retry-count" => 2 })
      expect(consumer.send(:extract_retry_count, properties)).to eq(2)
    end
  end

  describe "#handle_message" do
    it "raises NotImplementedError" do
      expect {
        consumer.send(:handle_message, "{}", double(headers: nil))
      }.to raise_error(NotImplementedError)
    end
  end
end
