class ConcatenationBuffer < ApplicationRecord
  belongs_to :sender

  validates :instance_name, presence: true
  validates :expires_at, presence: true

  scope :expired, -> { where("expires_at <= ?", Time.current) }
end
