module Strategies
  class MessageStrategyResolver
    STRATEGIES = {
      "conversation" => Strategies::ConversationStrategy,
      "audioMessage" => Strategies::AudioMessageStrategy
    }.freeze

    def self.resolve(message_type)
      STRATEGIES.fetch(message_type) do
        raise ArgumentError, "Unknown message type: #{message_type}"
      end
    end
  end
end
