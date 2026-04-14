class ConcatenationFlushJob < ApplicationJob
  queue_as :high_priority

  def perform(buffer_id:, expected_expires_at:)
    buffer = ConcatenationBuffer.find_by(id: buffer_id)
    return if buffer.nil?

    expected_time = Time.parse(expected_expires_at)

    # Only flush if the expiry hasn't been pushed forward by a newer message.
    # If expires_at moved, a newer flush job is scheduled and this one is stale.
    return unless buffer.expires_at <= expected_time + 0.1.seconds

    # Safety: don't flush before the window actually expires
    if buffer.expires_at > Time.current
      ConcatenationFlushJob.set(wait_until: buffer.expires_at).perform_later(
        buffer_id: buffer.id,
        expected_expires_at: buffer.expires_at.iso8601(6)
      )
      return
    end

    flush(buffer)
  rescue ActiveRecord::RecordNotFound
    # Buffer was already flushed and destroyed by a concurrent worker — safe to ignore.
    nil
  end

  private

  def flush(buffer)
    buffer.with_lock do
      return if buffer.expires_at > Time.current

      sender = buffer.sender

      ProcessedMessagePublisher.publish(
        sender: sender,
        text: buffer.accumulated_text
      )

      Rails.logger.info(
        "[ConcatenationFlush] Flushed #{buffer.message_count} messages " \
        "for sender=#{sender.id}, instance=#{buffer.instance_name}"
      )

      buffer.destroy!
    end
  end
end
