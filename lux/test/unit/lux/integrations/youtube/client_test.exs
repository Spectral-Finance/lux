defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes authenticated Data API requests" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]

        query = URI.decode_query(conn.query_string)
        assert query["part"] == "snippet"
        assert query["mine"] == "true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, %{"items" => []}} =
               Client.request(:get, "/channels", params: %{part: "snippet", mine: true})
    end

    test "returns YouTube API errors with status and details" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{
              "code" => 403,
              "message" => "Live Streaming API has not been enabled",
              "errors" => [%{"reason" => "liveStreamingNotEnabled"}]
            }
          })
        )
      end)

      assert {:error,
              {403, "Live Streaming API has not been enabled",
               [%{"reason" => "liveStreamingNotEnabled"}]}} =
               Client.request(:get, "/liveBroadcasts", params: %{part: "snippet"})
    end
  end

  describe "raw_request/3" do
    test "targets upload endpoint and preserves resumable upload headers" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]
        assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["4096"]

        conn
        |> Plug.Conn.put_resp_header("location", "https://upload.youtube.com/session/abc")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, response} =
               Client.raw_request(:post, "/videos",
                 base: :upload,
                 params: %{uploadType: "resumable", part: "snippet,status"},
                 json: %{snippet: %{title: "Demo"}},
                 headers: [
                   {"X-Upload-Content-Type", "video/mp4"},
                   {"X-Upload-Content-Length", "4096"}
                 ]
               )

      assert Client.response_header(response, "location") ==
               "https://upload.youtube.com/session/abc"
    end
  end

  test "builds OAuth consent URLs with default YouTube scopes" do
    url =
      YouTube.oauth_authorization_url(%{
        client_id: "client-123",
        redirect_uri: "http://localhost:4000/oauth/youtube",
        state: "csrf-token"
      })

    parsed = URI.parse(url)
    query = URI.decode_query(parsed.query)

    assert parsed.host == "accounts.google.com"
    assert query["client_id"] == "client-123"
    assert query["redirect_uri"] == "http://localhost:4000/oauth/youtube"
    assert query["state"] == "csrf-token"
    assert query["response_type"] == "code"
    assert query["access_type"] == "offline"
    assert String.contains?(query["scope"], "https://www.googleapis.com/auth/youtube.upload")
  end
end
