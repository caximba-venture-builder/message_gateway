require "rails_helper"

RSpec.describe BaseStrategy do
  let(:parsed_message) { double("ParsedMessage") }
  let(:sender) { double("Sender") }
  let(:strategy) { described_class.new(parsed_message, sender) }

  describe "#call" do
    it "raises NotImplementedError" do
      expect { strategy.call }.to raise_error(NotImplementedError, /must implement #call/)
    end
  end
end
