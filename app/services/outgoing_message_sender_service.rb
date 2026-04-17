class OutgoingMessageSenderService
  DEFAULT_DELAY_MS_PER_CHAR = 35
  MAX_DELAY_MS = 15_000

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
    sleep(0.5)
    client.send_text(number: @phone_number, text: @text)
  end

  private

  def client
    @client ||= EvolutionApiClient.new(instance_name: @instance_name)
  end

  def compute_delay_ms(text)
    delay_per_char = ENV.fetch("OUTGOING_TYPING_DELAY_MS_PER_CHAR", DEFAULT_DELAY_MS_PER_CHAR).to_i
    raw_delay = delay_per_char * text.to_s.length
    [ raw_delay, MAX_DELAY_MS ].min
  end
end
