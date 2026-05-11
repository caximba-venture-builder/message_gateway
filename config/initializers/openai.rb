OpenAI.configure do |config|
  config.request_timeout = ENV.fetch("OPENAI_REQUEST_TIMEOUT", 120).to_i
end
