class InstanceNameValidator
  class InvalidInstanceNameError < StandardError; end

  FORMAT = /\A[a-z0-9][a-z0-9_-]{0,63}\z/.freeze

  def self.call!(raw)
    new(raw).call!
  end

  def initialize(raw)
    @raw = raw
  end

  def call!
    value = @raw.to_s

    unless FORMAT.match?(value)
      raise InvalidInstanceNameError,
            "instance_name #{value.inspect} must match #{FORMAT.source}"
    end

    value
  end
end
