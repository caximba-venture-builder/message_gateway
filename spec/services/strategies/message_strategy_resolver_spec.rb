require "rails_helper"

RSpec.describe Strategies::MessageStrategyResolver do
  describe ".resolve" do
    it "returns ConversationStrategy for conversation type" do
      expect(described_class.resolve("conversation")).to eq(Strategies::ConversationStrategy)
    end

    it "returns AudioMessageStrategy for audioMessage type" do
      expect(described_class.resolve("audioMessage")).to eq(Strategies::AudioMessageStrategy)
    end

    it "raises ArgumentError for unknown type" do
      expect {
        described_class.resolve("imageMessage")
      }.to raise_error(ArgumentError, /Unknown message type: imageMessage/)
    end
  end
end
