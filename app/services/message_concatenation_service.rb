class MessageConcatenationService
  CONCAT_WINDOW = ConcatenationBufferRepository::CONCAT_WINDOW
  MAX_ACCUMULATED_BYTES = ConcatenationBufferRepository::MAX_ACCUMULATED_BYTES

  def self.call(sender:, instance_name:, text:)
    new(sender: sender, instance_name: instance_name, text: text).call
  end

  def initialize(sender:, instance_name:, text:)
    @sender = sender
    @instance_name = instance_name
    @text = text
  end

  def call
    buffer, expires_at = ConcatenationBufferRepository.append(
      sender: @sender,
      instance_name: @instance_name,
      text: @text
    )
    ConcatenationFlushScheduler.schedule(buffer: buffer, expires_at: expires_at)
  end
end
