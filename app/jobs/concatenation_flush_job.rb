class ConcatenationFlushJob < ApplicationJob
  queue_as :high_priority

  STALE_JOB_TOLERANCE = 0.1.seconds

  def perform(buffer_id:, expected_expires_at:)
    buffer = ConcatenationBuffer.find_by(id: buffer_id)
    return if buffer.nil?

    expected_time = Time.parse(expected_expires_at)

    buffer.with_lock do
      return if stale?(buffer, expected_time)

      if buffer.expires_at > Time.current
        reschedule(buffer)
        return
      end

      flush(buffer)
    end
  rescue ActiveRecord::RecordNotFound
    # Buffer was already flushed and destroyed by a concurrent worker — safe to ignore.
    nil
  end

  private

  def stale?(buffer, expected_time)
    buffer.expires_at > expected_time + STALE_JOB_TOLERANCE
  end

  def reschedule(buffer)
    ConcatenationFlushJob.set(wait_until: buffer.expires_at).perform_later(
      buffer_id: buffer.id,
      expected_expires_at: buffer.expires_at.iso8601(6)
    )
  end

  def flush(buffer)
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
