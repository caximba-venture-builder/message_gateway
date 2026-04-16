class OutgoingMessageSenderService
  DEFAULT_DELAY_MS_PER_CHAR = 35

  def self.call(...)
    new(...).call
  end

  def initialize(instance_name:, phone_number:, text:)
    @instance_name = instance_name
    @phone_number = phone_number
    @text = text
  end

  def call
    delay_ms = compute_delay_ms(@text)

    client.send_presence(number: @phone_number, delay_ms: delay_ms)
    sleep(delay_ms / 1000.0)
    client.send_text(number: @phone_number, text: @text)
  end

  private

  def client
    @client ||= EvolutionApiClient.new(instance_name: @instance_name)
  end

  def compute_delay_ms(text)
    delay_per_char = ENV.fetch("OUTGOING_TYPING_DELAY_MS_PER_CHAR", DEFAULT_DELAY_MS_PER_CHAR).to_i
    delay_per_char * text.to_s.length
  end
end
