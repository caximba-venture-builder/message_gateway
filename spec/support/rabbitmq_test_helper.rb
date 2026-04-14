class FakePublisher
  PublishedMessage = Data.define(:queue_name, :payload)

  class << self
    def messages
      @messages ||= []
    end

    def reset!
      @messages = []
    end

    def last_message
      messages.last
    end

    def messages_for(queue_name)
      messages.select { |m| m.queue_name == queue_name }
    end
  end
end

RSpec.configure do |config|
  config.before do
    FakePublisher.reset!
  end
end
