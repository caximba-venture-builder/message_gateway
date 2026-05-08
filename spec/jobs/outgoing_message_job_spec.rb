require "rails_helper"

RSpec.describe OutgoingMessageJob do
  let(:args) do
    { instance_name: "materny-bot-ai", phone_number: "5511999999999", text: "Olá!" }
  end

  describe "#perform" do
    it "delegates to OutgoingMessageSenderService with the given args" do
      allow(OutgoingMessageSenderService).to receive(:call)

      described_class.new.perform(**args)

      expect(OutgoingMessageSenderService).to have_received(:call).with(**args)
    end
  end

  describe "retry behavior" do
    it "re-enqueues itself when OutgoingMessageSenderService raises EvolutionApiClient::ApiError" do
      allow(OutgoingMessageSenderService).to receive(:call).and_raise(EvolutionApiClient::ApiError, "boom")

      job = described_class.new(**args)
      job.exception_executions = {}

      expect {
        job.perform_now
      }.to have_enqueued_job(described_class).with(**args)
    end
  end
end
