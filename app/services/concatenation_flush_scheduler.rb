class ConcatenationFlushScheduler
  def self.schedule(buffer:, expires_at:)
    ConcatenationFlushJob.set(wait_until: expires_at).perform_later(
      buffer_id: buffer.id,
      expected_expires_at: expires_at.iso8601(6)
    )
  end
end
