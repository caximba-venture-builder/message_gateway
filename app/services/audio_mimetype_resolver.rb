class AudioMimetypeResolver
  EXTENSIONS = {
    "audio/ogg" => ".ogg",
    "audio/mpeg" => ".mp3",
    "audio/mp4" => ".m4a",
    "audio/wav" => ".wav"
  }.freeze
  DEFAULT_EXTENSION = ".ogg"

  def self.extension_for(mimetype)
    base = mimetype.to_s.split(";").first.to_s.strip
    EXTENSIONS.fetch(base, DEFAULT_EXTENSION)
  end
end
