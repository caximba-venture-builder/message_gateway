class ConversationStrategy < BaseStrategy
  def call
    MessageConcatenationService.call(
      sender: @sender,
      instance_name: @parsed_message.instance_name,
      text: @parsed_message.message_body
    )
  end
end
