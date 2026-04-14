class Message < ApplicationRecord
  belongs_to :sender

  validates :whatsapp_message_id, presence: true
  validates :message_type, presence: true, inclusion: { in: %w[conversation audioMessage] }
  validates :message_timestamp, presence: true
end
