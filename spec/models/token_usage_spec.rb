require "rails_helper"

RSpec.describe TokenUsage, type: :model do
  subject { build(:token_usage) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires tokens_used" do
      subject.tokens_used = nil
      expect(subject).not_to be_valid
    end

    it "requires non-negative tokens_used" do
      subject.tokens_used = -1
      expect(subject).not_to be_valid
    end

    it "accepts zero tokens_used" do
      subject.tokens_used = 0
      expect(subject).to be_valid
    end

    it "requires sender" do
      subject.sender = nil
      expect(subject).not_to be_valid
    end

    it "requires message" do
      subject.message = nil
      expect(subject).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to sender" do
      token_usage = create(:token_usage)
      expect(token_usage.sender).to be_a(Sender)
    end

    it "belongs to message" do
      token_usage = create(:token_usage)
      expect(token_usage.message).to be_a(Message)
    end
  end
end
