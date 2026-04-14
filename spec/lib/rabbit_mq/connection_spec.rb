require "rails_helper"

RSpec.describe RabbitMq::Connection do
  after do
    described_class.reset!
  end

  describe ".instance" do
    it "creates a Bunny connection" do
      mock_connection = instance_double(Bunny::Session, open?: true, start: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(mock_connection)

      result = described_class.instance

      expect(result).to eq(mock_connection)
      expect(mock_connection).to have_received(:start)
    end

    it "reuses existing open connection" do
      mock_connection = instance_double(Bunny::Session, open?: true, start: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(mock_connection)

      first = described_class.instance
      second = described_class.instance

      expect(first).to eq(second)
      expect(Bunny).to have_received(:new).once
    end

    it "reconnects if connection is closed" do
      closed_conn = instance_double(Bunny::Session, open?: false, start: nil, host: "localhost")
      new_conn = instance_double(Bunny::Session, open?: true, start: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(closed_conn, new_conn)

      described_class.instance # gets closed_conn, which reports open? false
      described_class.reset!

      # After reset, next call creates new connection
      result = described_class.instance
      expect(Bunny).to have_received(:new).twice
    end
  end

  describe ".close" do
    it "closes an open connection" do
      mock_connection = instance_double(Bunny::Session, open?: true, start: nil, close: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(mock_connection)

      described_class.instance
      described_class.close

      expect(mock_connection).to have_received(:close)
    end
  end

  describe ".reset!" do
    it "clears the connection without closing" do
      mock_connection = instance_double(Bunny::Session, open?: true, start: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(mock_connection)

      described_class.instance
      described_class.reset!

      # Should create a new connection on next call
      new_conn = instance_double(Bunny::Session, open?: true, start: nil, host: "localhost")
      allow(Bunny).to receive(:new).and_return(new_conn)

      result = described_class.instance
      expect(result).to eq(new_conn)
    end
  end
end
