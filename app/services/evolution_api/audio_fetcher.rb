module EvolutionApi
  class AudioFetcher
    class FetchError < StandardError; end

    def self.call(server_url:, instance_name:, api_key:, message:)
      new(server_url: server_url, instance_name: instance_name, api_key: api_key, message: message).call
    end

    def initialize(server_url:, instance_name:, api_key:, message:)
      @server_url = server_url
      @instance_name = instance_name
      @api_key = api_key
      @message = message
    end

    def call
      uri = URI.parse("#{@server_url}/chat/getBase64FromMediaMessage/#{@instance_name}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["apikey"] = @api_key
      request.body = { message: @message }.to_json

      response = http.request(request)
      Rails.logger.info("[EvolutionApi::AudioFetcher] Response HTTP #{response.code} for instance=#{@instance_name}")

      raise FetchError, "Evolution API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      raise FetchError, "Evolution API response missing base64 data" unless parsed["base64"].present?

      { base64: parsed["base64"], mimetype: parsed["mimetype"] }
    rescue JSON::ParserError => e
      raise FetchError, "Invalid JSON from Evolution API: #{e.message}"
    end
  end
end
