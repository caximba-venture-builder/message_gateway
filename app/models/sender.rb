class Sender < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_many :token_usages, dependent: :destroy
  has_many :concatenation_buffers, dependent: :destroy

  validates :phone_number, presence: true, uniqueness: true,
            format: { with: /\A\d{10,15}\z/ }
  validates :push_name, presence: true, length: { maximum: 100 }
end
