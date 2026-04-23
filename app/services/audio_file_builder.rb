class AudioFileBuilder
  class EmptyAudioError < StandardError; end

  def self.call(binary:, mimetype:)
    raise EmptyAudioError, "Audio data is empty" if binary.empty?

    extension = AudioMimetypeResolver.extension_for(mimetype)
    tempfile = Tempfile.new([ "whisper_audio", extension ])
    tempfile.binmode
    tempfile.write(binary)
    tempfile.rewind
    tempfile
  end
end
