class AudioDownloader < ApplicationHttpClient
  class DownloadError < StandardError; end

  MAX_REDIRECTS = 3

  def self.call(url:)
    new(url: url).call
  end

  def initialize(url:)
    @url = url
    @redirects = 0
  end

  def call
    binary = fetch(@url)
    raise DownloadError, "Downloaded audio is empty" if binary.empty?

    { binary: binary }
  end

  private

  def fetch(url)
    uri = URI.parse(url)
    http = build_http(uri)

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    Rails.logger.info("[AudioDownloader] Response HTTP #{response.code} for #{uri.host}")

    case response
    when Net::HTTPSuccess
      response.body.to_s.force_encoding(Encoding::BINARY)
    when Net::HTTPRedirection
      @redirects += 1
      raise DownloadError, "Too many redirects for audio download" if @redirects > MAX_REDIRECTS

      fetch(response["Location"])
    else
      raise DownloadError, "Audio download failed with HTTP #{response.code}"
    end
  rescue URI::InvalidURIError, *NETWORK_ERRORS => e
    raise DownloadError, "Audio download error: #{e.message}"
  end
end
