class ApplicationHttpClient
  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_READ_TIMEOUT = 30
  NETWORK_ERRORS = [ SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout ].freeze

  private

  def build_http(uri, open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout
    http
  end
end
