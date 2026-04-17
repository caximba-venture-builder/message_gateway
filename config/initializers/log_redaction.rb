Rails.application.config.filter_parameters += [
  :text,
  :message_body,
  :accumulated_text,
  :push_name,
  :apikey,
  :api_key
]
