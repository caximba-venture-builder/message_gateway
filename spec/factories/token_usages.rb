FactoryBot.define do
  factory :token_usage do
    sender
    message
    tokens_used { rand(10..500) }
    transcription_model { "whisper-1" }
  end
end
