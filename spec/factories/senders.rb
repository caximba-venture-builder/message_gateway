FactoryBot.define do
  factory :sender do
    phone_number { Faker::PhoneNumber.unique.phone_number.gsub(/\D/, "") }
    push_name { Faker::Name.name }
    os { %w[android ios].sample }
  end
end
