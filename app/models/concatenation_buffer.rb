class ConcatenationBuffer < ApplicationRecord
  belongs_to :sender

  validates :instance_name, presence: true, length: { maximum: 64 },
            format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ }
  validates :expires_at, presence: true
  validates :accumulated_text, length: { maximum: 16_384 }
  validates :message_count, numericality: { less_than_or_equal_to: 100 }

  scope :expired, -> { where("expires_at <= ?", Time.current) }
end
