class TokenUsage < ApplicationRecord
  belongs_to :sender
  belongs_to :message

  validates :tokens_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
