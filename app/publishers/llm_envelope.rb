class LlmEnvelope
  OPEN_TAG = "<user_message>"
  CLOSE_TAG = "</user_message>"

  def self.enabled?
    ENV.fetch("LLM_ENVELOPE_ENABLED", "false") == "true"
  end

  def self.wrap(text:, name:)
    { text: "#{OPEN_TAG}#{escape(text)}#{CLOSE_TAG}", name: escape(name) }
  end

  def self.escape(value)
    value.to_s
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
  end
end
