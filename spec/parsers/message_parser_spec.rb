require "rails_helper"

RSpec.describe MessageParser do
  describe ".call" do
    context "with a valid text message payload" do
      let(:payload) { build_text_message_payload }

      it "returns a ParsedMessage" do
        result = described_class.call(payload)
        expect(result).to be_a(ValueObjects::ParsedMessage)
      end

      it "extracts the event" do
        result = described_class.call(payload)
        expect(result.event).to eq("messages.upsert")
      end

      it "extracts the instance name" do
        result = described_class.call(payload)
        expect(result.instance_name).to eq("materny-bot-ai")
      end

      it "extracts phone number without @s.whatsapp.net" do
        result = described_class.call(payload)
        expect(result.sender_phone_number).to eq("5511999999999")
      end

      it "extracts the whatsapp message id" do
        result = described_class.call(payload)
        expect(result.whatsapp_message_id).to eq("3EB0A0C1D2E3F4A5B6C7D8")
      end

      it "extracts push_name" do
        result = described_class.call(payload)
        expect(result.push_name).to eq("João Silva")
      end

      it "extracts message_type as conversation" do
        result = described_class.call(payload)
        expect(result.message_type).to eq("conversation")
      end

      it "extracts message_timestamp as integer" do
        result = described_class.call(payload)
        expect(result.message_timestamp).to eq(1713105000)
      end

      it "extracts source_os" do
        result = described_class.call(payload)
        expect(result.source_os).to eq("android")
      end

      it "extracts message_body for conversation type" do
        result = described_class.call(payload)
        expect(result.message_body).to eq("Olá, tudo bem?")
      end

      it "sets audio fields to nil for conversation type" do
        result = described_class.call(payload)
        expect(result.media_url).to be_nil
        expect(result.audio_mimetype).to be_nil
      end

      it "preserves the raw_payload" do
        result = described_class.call(payload)
        expect(result.raw_payload).to be_a(Hash)
      end
    end

    context "with a valid audio message payload" do
      let(:payload) { build_audio_message_payload }

      it "extracts message_type as audioMessage" do
        result = described_class.call(payload)
        expect(result.message_type).to eq("audioMessage")
      end

      it "extracts media_url" do
        result = described_class.call(payload)
        expect(result.media_url).to eq("https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123")
      end

      it "extracts audio_mimetype" do
        result = described_class.call(payload)
        expect(result.audio_mimetype).to eq("audio/ogg; codecs=opus")
      end

      it "sets message_body to nil for audio type" do
        result = described_class.call(payload)
        expect(result.message_body).to be_nil
      end
    end

    context "with missing data field" do
      it "raises ParseError" do
        payload = { "event" => "messages.upsert", "sender" => "123@s.whatsapp.net" }
        expect { described_class.call(payload) }.to raise_error(MessageParser::ParseError, "Missing 'data' field")
      end
    end

    context "with missing sender field" do
      it "raises ParseError" do
        payload = build_text_message_payload.except("sender")
        expect { described_class.call(payload) }.to raise_error(MessageParser::ParseError, "Missing 'sender' field")
      end
    end

    context "with missing data.key.id" do
      it "raises ParseError" do
        payload = build_text_message_payload
        payload["data"]["key"].delete("id")
        expect { described_class.call(payload) }.to raise_error(MessageParser::ParseError, "Missing 'data.key.id'")
      end
    end

    context "with missing messageType" do
      it "raises ParseError" do
        payload = build_text_message_payload
        payload["data"].delete("messageType")
        expect { described_class.call(payload) }.to raise_error(MessageParser::ParseError, "Missing 'data.messageType'")
      end
    end

    context "with unsupported messageType" do
      it "raises ParseError" do
        payload = build_text_message_payload("data" => { "key" => { "id" => "123" }, "messageType" => "imageMessage" })
        expect { described_class.call(payload) }.to raise_error(MessageParser::ParseError, /Unsupported messageType: imageMessage/)
      end
    end

    context "with string keys" do
      it "handles string keys correctly" do
        payload = build_text_message_payload
        result = described_class.call(payload)
        expect(result.sender_phone_number).to eq("5511999999999")
      end
    end

    context "with symbol keys" do
      it "handles symbol keys correctly" do
        payload = build_text_message_payload.deep_symbolize_keys
        result = described_class.call(payload)
        expect(result.sender_phone_number).to eq("5511999999999")
      end
    end
  end
end
