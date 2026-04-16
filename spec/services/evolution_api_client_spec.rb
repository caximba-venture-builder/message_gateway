require "rails_helper"

RSpec.describe EvolutionApiClient do
  let(:instance_name) { "materny-bot-ai" }
  let(:client) { described_class.new(instance_name: instance_name) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EVOLUTION_API_URL").and_return("https://evo.example.com")
    allow(ENV).to receive(:fetch).with("EVOLUTION_API_KEY").and_return("secret-key")
  end

  describe "#send_presence" do
    let(:endpoint) { "https://evo.example.com/chat/sendPresence/materny-bot-ai" }

    it "posts the presence payload with apikey header" do
      stub = stub_request(:post, endpoint)
        .with(
          headers: { "Content-Type" => "application/json", "apikey" => "secret-key" },
          body: {
            number: "5511999999999",
            presence: "composing",
            delay: 1050
          }.to_json
        )
        .to_return(status: 201, body: "{}")

      client.send_presence(number: "5511999999999", delay_ms: 1050)

      expect(stub).to have_been_requested
    end

    it "raises ApiError on non-2xx response" do
      stub_request(:post, endpoint).to_return(status: 500, body: "boom")

      expect {
        client.send_presence(number: "5511999999999", delay_ms: 1050)
      }.to raise_error(EvolutionApiClient::ApiError, /HTTP 500/)
    end
  end

  describe "#send_text" do
    let(:endpoint) { "https://evo.example.com/message/sendText/materny-bot-ai" }

    it "posts the text payload" do
      stub = stub_request(:post, endpoint)
        .with(
          headers: { "apikey" => "secret-key" },
          body: { number: "5511999999999", text: "Olá!" }.to_json
        )
        .to_return(status: 201, body: "{}")

      client.send_text(number: "5511999999999", text: "Olá!")

      expect(stub).to have_been_requested
    end

    it "includes delay when provided" do
      stub = stub_request(:post, endpoint)
        .with(body: { number: "5511999999999", text: "Olá!", delay: 500 }.to_json)
        .to_return(status: 201, body: "{}")

      client.send_text(number: "5511999999999", text: "Olá!", delay_ms: 500)

      expect(stub).to have_been_requested
    end

    it "wraps network errors as ApiError" do
      stub_request(:post, endpoint).to_raise(SocketError.new("dns fail"))

      expect {
        client.send_text(number: "5511999999999", text: "Olá!")
      }.to raise_error(EvolutionApiClient::ApiError, /network error/)
    end
  end
end
