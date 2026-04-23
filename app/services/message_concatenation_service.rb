class MessageConcatenationService
  CONCAT_WINDOW = ENV.fetch("MESSAGE_CONVERSATION_CONCAT_WINDOW", "30").to_i
  MAX_ACCUMULATED_BYTES = 8192

  def self.call(sender:, instance_name:, text:)
    new(sender: sender, instance_name: instance_name, text: text).call
  end

  def initialize(sender:, instance_name:, text:)
    @sender = sender
    @instance_name = instance_name
    @text = text
  end

  def call
    buffer = ConcatenationBuffer.find_or_initialize_by(
      sender: @sender,
      instance_name: @instance_name
    )

    expires_at = buffer.new_record? ? save_new_buffer(buffer) : update_existing_buffer(buffer)

    schedule_flush(buffer, expires_at)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  def save_new_buffer(buffer)
    buffer.accumulated_text = @text
    buffer.message_count = 1
    buffer.expires_at = CONCAT_WINDOW.seconds.from_now
    buffer.save!
    buffer.expires_at
  end

  def update_existing_buffer(buffer)
    buffer.with_lock do
      separator = buffer.accumulated_text.present? ? "\n" : ""
      buffer.accumulated_text = "#{buffer.accumulated_text}#{separator}#{@text}"
      buffer.message_count += 1
      buffer.expires_at = overflow?(buffer) ? Time.current : CONCAT_WINDOW.seconds.from_now
      buffer.save!
      buffer.expires_at
    end
  end

  def overflow?(buffer)
    buffer.accumulated_text.bytesize > MAX_ACCUMULATED_BYTES
  end

  def schedule_flush(buffer, expires_at)
    ConcatenationFlushJob.set(wait_until: expires_at).perform_later(
      buffer_id: buffer.id,
      expected_expires_at: expires_at.iso8601(6)
    )
  end
end
