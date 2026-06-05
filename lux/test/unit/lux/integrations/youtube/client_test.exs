defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  describe "authorization_url/1" do
    test "builds an offline OAuth consent URL with YouTube scopes" do
      url =
        Client.authorization_url(%{
          client_id: "client-id",
          redirect_uri: "https://example.test/oauth",
          state: "state-1"
        })

      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth?")
      assert url =~ "client_id=client-id"
      assert url =~ "access_type=offline"
      assert url =~ "prompt=consent"
      assert url =~ "state=state-1"
      assert url =~ URI.encode_www_form("https://www.googleapis.com/auth/youtube.upload")
    end
  end

  describe "integration defaults" do
    test "exposes default headers and scopes through the integration module" do
      assert Lux.Integrations.YouTube.headers() == [{"Content-Type", "application/json"}]
      assert "https://www.googleapis.com/auth/youtube.force-ssl" in Lux.Integrations.YouTube.scopes()
    end
  end

  describe "token_request/2" do
    test "builds authorization-code and refresh-token requests" do
      exchange =
        Client.token_request(:authorization_code, %{
          client_id: "client-id",
          client_secret: "secret",
          code: "code",
          redirect_uri: "https://example.test/oauth"
        })

      assert exchange.method == :post
      assert exchange.form.grant_type == "authorization_code"
      assert exchange.form.code == "code"

      refresh =
        Client.token_request(:refresh_token, %{
          client_id: "client-id",
          client_secret: "secret",
          refresh_token: "refresh"
        })

      assert refresh.form.grant_type == "refresh_token"
      assert refresh.form.refresh_token == "refresh"
    end
  end

  describe "build_request/3" do
    test "normalizes query keys and adds bearer authorization" do
      request =
        Client.build_request(:get, "/liveBroadcasts", %{
          access_token: "token",
          query: %{broadcast_status: "all", max_results: 50, part: ["snippet", "status"]}
        })

      assert request.url == "https://www.googleapis.com/youtube/v3/liveBroadcasts"
      assert request.query == %{"broadcastStatus" => "all", "maxResults" => 50, "part" => "snippet,status"}
      assert {"Authorization", "Bearer token"} in request.headers
    end
  end

  describe "resumable_upload_request/1" do
    test "builds a resumable videos.insert request" do
      request =
        Client.resumable_upload_request(%{
          access_token: "token",
          title: "Launch stream",
          description: "Archive",
          tags: ["lux", "live"],
          privacy_status: "unlisted",
          content_length: 123_456
        })

      assert request.method == :post
      assert request.url == "https://www.googleapis.com/upload/youtube/v3/videos"
      assert request.query == %{"uploadType" => "resumable", "part" => "snippet,status"}
      assert request.json.snippet.title == "Launch stream"
      assert request.json.status.privacyStatus == "unlisted"
      assert {"X-Upload-Content-Length", "123456"} in request.headers
    end
  end

  describe "resumable upload session helpers" do
    test "builds chunk upload and resume probe requests against the Location URL" do
      chunk =
        Client.resumable_chunk_request(%{
          access_token: "token",
          upload_url: "https://upload.youtube.test/session",
          content_type: "video/mp4",
          content_length: "256",
          range_start: 0,
          total_length: "1024"
        })

      assert chunk.method == :put
      assert chunk.url == "https://upload.youtube.test/session"
      assert {"Authorization", "Bearer token"} in chunk.headers
      assert {"Content-Length", "256"} in chunk.headers
      assert {"Content-Range", "bytes 0-255/1024"} in chunk.headers
      assert chunk.body == :video_binary

      resume =
        Client.resumable_resume_request(%{
          upload_url: "https://upload.youtube.test/session",
          total_length: "1024"
        })

      assert resume.method == :put
      assert resume.url == "https://upload.youtube.test/session"
      assert {"Content-Length", "0"} in resume.headers
      assert {"Content-Range", "bytes */1024"} in resume.headers
      assert resume.body == ""
    end
  end
end
