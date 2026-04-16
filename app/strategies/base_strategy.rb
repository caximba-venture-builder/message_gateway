class BaseStrategy
  def initialize(parsed_message, sender)
    @parsed_message = parsed_message
    @sender = sender
  end

  def call
    raise NotImplementedError, "#{self.class} must implement #call"
  end
end
