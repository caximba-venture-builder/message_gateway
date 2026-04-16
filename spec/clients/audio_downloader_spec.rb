require "rails_helper"

RSpec.describe AudioDownloader do
  let(:media_url) { "https://bucket.example.com/audio/test_audio.oga?X-Amz-Signature=abc123" }

  describe ".call" do
    context "when download succeeds" do
      before do
        stub_request(:get, media_url)
          .to_return(
            status: 200,
            body: "fake ogg binary content",
            headers: { "Content-Type" => "audio/ogg" }
          )
      end

      it "returns binary audio data" do
        result = described_class.call(url: media_url)
        expect(result[:binary]).to eq("fake ogg binary content".b)
      end

      it "returns binary with BINARY encoding" do
        result = described_class.call(url: media_url)
        expect(result[:binary].encoding).to eq(Encoding::BINARY)
      end
    end

    context "when server returns non-200 status" do
      before do
        stub_request(:get, media_url).to_return(status: 403, body: "Forbidden")
      end

      it "raises DownloadError" do
        expect {
          described_class.call(url: media_url)
        }.to raise_error(AudioDownloader::DownloadError, /HTTP 403/)
      end
    end

    context "when server returns empty body" do
      before do
        stub_request(:get, media_url).to_return(status: 200, body: "")
      end

      it "raises DownloadError" do
        expect {
          described_class.call(url: media_url)
        }.to raise_error(AudioDownloader::DownloadError, /empty/)
      end
    end

    context "when server redirects" do
      let(:redirect_url) { "https://cdn.example.com/audio/redirected.oga" }

      before do
        stub_request(:get, media_url)
          .to_return(status: 302, headers: { "Location" => redirect_url })
        stub_request(:get, redirect_url)
          .to_return(status: 200, body: "redirected audio content")
      end

      it "follows the redirect and returns the audio binary" do
        result = described_class.call(url: media_url)
        expect(result[:binary]).to eq("redirected audio content".b)
      end
    end

    context "when there are too many redirects" do
      before do
        stub_request(:get, media_url)
          .to_return(status: 302, headers: { "Location" => media_url })
      end

      it "raises DownloadError after max redirects" do
        expect {
          described_class.call(url: media_url)
        }.to raise_error(AudioDownloader::DownloadError, /Too many redirects/)
      end
    end

    context "when a network error occurs" do
      before do
        stub_request(:get, media_url).to_raise(SocketError.new("connection refused"))
      end

      it "raises DownloadError with network error message" do
        expect {
          described_class.call(url: media_url)
        }.to raise_error(AudioDownloader::DownloadError, /Audio download error/)
      end
    end

    context "when connection times out" do
      before do
        stub_request(:get, media_url).to_raise(Net::OpenTimeout)
      end

      it "raises DownloadError" do
        expect {
          described_class.call(url: media_url)
        }.to raise_error(AudioDownloader::DownloadError, /Audio download error/)
      end
    end
  end
end
