require "rails_helper"

RSpec.describe EvolutionApi::AudioFetcher do
  let(:server_url)    { "https://evolution.example.com" }
  let(:instance_name) { "materny-bot-ai" }
  let(:api_key)       { "test-api-key" }
  let(:message)       { { "audioMessage" => { "url" => "https://mmg.whatsapp.net/audio.enc" } } }
  let(:endpoint)      { "#{server_url}/chat/getBase64FromMediaMessage/#{instance_name}" }

  describe ".call" do
    context "when Evolution API returns base64 successfully" do
      before do
        stub_request(:post, endpoint)
          .with(
            headers: { "apikey" => api_key, "Content-Type" => "application/json" },
            body: { message: message }.to_json
          )
          .to_return(
            status: 200,
            body: { "base64" => "ZmFrZWF1ZGlv", "mimetype" => "audio/ogg; codecs=opus" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns base64 and mimetype" do
        result = described_class.call(
          server_url: server_url,
          instance_name: instance_name,
          api_key: api_key,
          message: message
        )

        expect(result[:base64]).to eq("ZmFrZWF1ZGlv")
        expect(result[:mimetype]).to eq("audio/ogg; codecs=opus")
      end
    end

    context "when Evolution API returns a non-200 status" do
      before do
        stub_request(:post, endpoint).to_return(status: 500, body: "Internal Server Error")
      end

      it "raises FetchError" do
        expect {
          described_class.call(
            server_url: server_url,
            instance_name: instance_name,
            api_key: api_key,
            message: message
          )
        }.to raise_error(EvolutionApi::AudioFetcher::FetchError, /HTTP 500/)
      end
    end

    context "when Evolution API response is missing base64" do
      before do
        stub_request(:post, endpoint)
          .to_return(
            status: 200,
            body: { "error" => "media not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises FetchError" do
        expect {
          described_class.call(
            server_url: server_url,
            instance_name: instance_name,
            api_key: api_key,
            message: message
          )
        }.to raise_error(EvolutionApi::AudioFetcher::FetchError, /missing base64/)
      end
    end

    context "when Evolution API returns invalid JSON" do
      before do
        stub_request(:post, endpoint).to_return(status: 200, body: "not json")
      end

      it "raises FetchError" do
        expect {
          described_class.call(
            server_url: server_url,
            instance_name: instance_name,
            api_key: api_key,
            message: message
          )
        }.to raise_error(EvolutionApi::AudioFetcher::FetchError, /Invalid JSON/)
      end
    end
  end
end
