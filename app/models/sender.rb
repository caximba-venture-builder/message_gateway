class Sender < ApplicationRecord
  has_many :messages, dependent: :destroy
  has_many :token_usages, dependent: :destroy
  has_many :concatenation_buffers, dependent: :destroy

  validates :phone_number, presence: true, uniqueness: true
  validates :push_name, presence: true
end
