FactoryBot.define do
  factory :concatenation_buffer do
    sender
    instance_name { "materny-bot-ai" }
    accumulated_text { "Hello" }
    expires_at { 30.seconds.from_now }
    message_count { 1 }
  end
end
