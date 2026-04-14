FactoryBot.define do
  factory :message do
    sender
    whatsapp_message_id { "3EB0#{SecureRandom.hex(8).upcase}" }
    message_type { "conversation" }
    message_timestamp { Time.current.to_i }
    sender_os { "android" }

    trait :conversation do
      message_type { "conversation" }
    end

    trait :audio do
      message_type { "audioMessage" }
    end
  end
end
