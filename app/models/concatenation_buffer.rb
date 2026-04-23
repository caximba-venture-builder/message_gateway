class ConcatenationBuffer < ApplicationRecord
  SOFT_MAX_BYTES = 8_192
  HARD_MAX_BYTES = 16_384
  MAX_MESSAGE_COUNT = 100
  INSTANCE_NAME_MAX_LENGTH = 64
  INSTANCE_NAME_FORMAT = /\A[a-z0-9][a-z0-9_-]*\z/

  belongs_to :sender

  validates :instance_name, presence: true, length: { maximum: INSTANCE_NAME_MAX_LENGTH },
            format: { with: INSTANCE_NAME_FORMAT }
  validates :expires_at, presence: true
  validates :accumulated_text, length: { maximum: HARD_MAX_BYTES }
  validates :message_count, numericality: { less_than_or_equal_to: MAX_MESSAGE_COUNT }

  scope :expired, -> { where("expires_at <= ?", Time.current) }
end
