class EvolutionApiClient < ApplicationHttpClient
  class ApiError < StandardError; end

  DEFAULT_PRESENCE = "composing".freeze

  def initialize(instance_name:)
    @instance_name = InstanceNameValidator.call!(instance_name)
  end

  def send_presence(number:, delay_ms:, presence: DEFAULT_PRESENCE)
    payload = {
      number: number,
      presence: presence,
      delay: delay_ms
    }

    post("/chat/sendPresence/#{@instance_name}", payload)
  end

  def send_text(number:, text:, delay_ms: nil)
    payload = { number: number, text: text }
    payload[:delay] = delay_ms if delay_ms

    post("/message/sendText/#{@instance_name}", payload)
  end

  private

  def post(path, payload)
    uri = URI.join(base_url, path)
    http = build_http(uri)

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["apikey"] = api_key
    request.body = payload.to_json

    Rails.logger.debug do
      "[EvolutionApiClient] POST #{path} number=#{mask_number(payload[:number])} text_bytes=#{payload[:text]&.bytesize}"
    end
    response = http.request(request)

    Rails.logger.info("[EvolutionApiClient] #{path} -> HTTP #{response.code}")

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "Evolution API #{path} failed with HTTP #{response.code}: #{response.body}"
    end

    response.body
  rescue *NETWORK_ERRORS => e
    raise ApiError, "Evolution API network error on #{path}: #{e.message}"
  end

  def base_url
    ENV.fetch("EVOLUTION_API_URL")
  end

  def api_key
    ENV.fetch("EVOLUTION_API_KEY")
  end

  def mask_number(number)
    digits = number.to_s
    return "[blank]" if digits.empty?

    "***#{digits[-4..]}"
  end
end
