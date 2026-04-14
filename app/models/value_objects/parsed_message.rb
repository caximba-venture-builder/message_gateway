module ValueObjects
  ParsedMessage = Data.define(
    :event,
    :instance_name,
    :server_url,
    :date_time,
    :sender_phone_number,
    :api_key,
    :whatsapp_message_id,
    :remote_jid,
    :push_name,
    :message_type,
    :message_timestamp,
    :source_os,
    :message_body,
    :audio_url,
    :audio_mimetype,
    :audio_file_length,
    :audio_message,
    :raw_payload
  )
end
