module PayloadHelpers
  def build_text_message_payload(overrides = {})
    {
      "event" => "messages.upsert",
      "instance" => "materny-bot-ai",
      "data" => {
        "key" => {
          "remoteJid" => "5511999999999@s.whatsapp.net",
          "fromMe" => false,
          "id" => "3EB0A0C1D2E3F4A5B6C7D8"
        },
        "pushName" => "João Silva",
        "status" => "DELIVERY_ACK",
        "message" => {
          "conversation" => "Olá, tudo bem?"
        },
        "contextInfo" => {},
        "messageType" => "conversation",
        "messageTimestamp" => 1713105000,
        "instanceId" => "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "source" => "android"
      },
      "server_url" => "https://your-evolution-api.com",
      "date_time" => "2026-04-14T15:30:00.000Z",
      "sender" => "5511999999999@s.whatsapp.net",
      "apikey" => "your-api-key"
    }.deep_merge(overrides)
  end

  def build_audio_message_payload(overrides = {})
    {
      "event" => "messages.upsert",
      "instance" => "materny-bot-ai",
      "data" => {
        "key" => {
          "remoteJid" => "5511999999999@s.whatsapp.net",
          "fromMe" => false,
          "id" => "3EB0B1C2D3E4F5A6B7C8D9"
        },
        "pushName" => "Maria Souza",
        "status" => "DELIVERY_ACK",
        "message" => {
          "audioMessage" => {
            "url" => "https://mmg.whatsapp.net/v/t62.7114-24/audio.enc",
            "mimetype" => "audio/ogg; codecs=opus",
            "fileSha256" => "base64-encoded-sha256",
            "fileLength" => 15230,
            "seconds" => 7,
            "ptt" => true,
            "mediaKey" => "base64-encoded-media-key",
            "fileEncSha256" => "base64-encoded-enc-sha256",
            "directPath" => "/v/t62.7114-24/audio.enc",
            "mediaKeyTimestamp" => 1713105200,
            "waveform" => "base64-encoded-waveform-data"
          }
        },
        "contextInfo" => {},
        "messageType" => "audioMessage",
        "messageTimestamp" => 1713105200,
        "instanceId" => "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "source" => "android"
      },
      "server_url" => "https://your-evolution-api.com",
      "date_time" => "2026-04-14T15:30:00.000Z",
      "sender" => "5511999999999@s.whatsapp.net",
      "apikey" => "your-api-key"
    }.deep_merge(overrides)
  end
end

RSpec.configure do |config|
  config.include PayloadHelpers
end
