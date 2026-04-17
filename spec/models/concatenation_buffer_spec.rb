require "rails_helper"

RSpec.describe ConcatenationBuffer, type: :model do
  subject { build(:concatenation_buffer) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires instance_name" do
      subject.instance_name = nil
      expect(subject).not_to be_valid
    end

    it "requires expires_at" do
      subject.expires_at = nil
      expect(subject).not_to be_valid
    end

    it "requires sender" do
      subject.sender = nil
      expect(subject).not_to be_valid
    end

    it "rejects instance_name longer than 64 characters" do
      subject.instance_name = "a" * 65
      expect(subject).not_to be_valid
    end

    it "rejects instance_name with uppercase or path characters" do
      subject.instance_name = "../evil"
      expect(subject).not_to be_valid
      subject.instance_name = "UpperCase"
      expect(subject).not_to be_valid
    end

    it "rejects accumulated_text longer than 16_384 bytes (hard cap)" do
      subject.accumulated_text = "a" * 16_385
      expect(subject).not_to be_valid
      expect(subject.errors[:accumulated_text]).to be_present
    end

    it "rejects message_count greater than 100" do
      subject.message_count = 101
      expect(subject).not_to be_valid
    end

    it "enforces unique sender_id + instance_name" do
      existing = create(:concatenation_buffer)
      subject.sender = existing.sender
      subject.instance_name = existing.instance_name
      expect { subject.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "scopes" do
    it ".expired returns buffers past their expiry" do
      expired = create(:concatenation_buffer, expires_at: 1.minute.ago)
      _active = create(:concatenation_buffer, expires_at: 1.minute.from_now)

      expect(ConcatenationBuffer.expired).to contain_exactly(expired)
    end
  end

  describe "associations" do
    it "belongs to sender" do
      buffer = create(:concatenation_buffer)
      expect(buffer.sender).to be_a(Sender)
    end
  end
end
