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
    new_expiry = CONCAT_WINDOW.seconds.from_now

    buffer = find_or_initialize_buffer
    append_to_buffer(buffer, new_expiry)

    if buffer.accumulated_text.bytesize > MAX_ACCUMULATED_BYTES
      buffer.update!(expires_at: Time.current)
      ConcatenationFlushJob.perform_later(
        buffer_id: buffer.id,
        expected_expires_at: buffer.expires_at.iso8601(6)
      )
    else
      schedule_flush(buffer)
    end
  end

  private

  def find_or_initialize_buffer
    ConcatenationBuffer.find_or_initialize_by(
      sender: @sender,
      instance_name: @instance_name
    )
  end

  def append_to_buffer(buffer, new_expiry)
    if buffer.new_record?
      buffer.accumulated_text = @text
      buffer.message_count = 1
      buffer.expires_at = new_expiry
      buffer.save!
    else
      buffer.with_lock do
        separator = buffer.accumulated_text.present? ? "\n" : ""
        buffer.accumulated_text = "#{buffer.accumulated_text}#{separator}#{@text}"
        buffer.message_count += 1
        buffer.expires_at = new_expiry
        buffer.save!
      end
    end
  rescue ActiveRecord::RecordNotUnique
    buffer = ConcatenationBuffer.find_by!(sender: @sender, instance_name: @instance_name)
    retry
  end

  def schedule_flush(buffer)
    ConcatenationFlushJob.set(wait_until: buffer.expires_at).perform_later(
      buffer_id: buffer.id,
      expected_expires_at: buffer.expires_at.iso8601(6)
    )
  end
end
