defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "OAuth token lifecycle" do
    test "exchanges an authorization code using form encoding" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/token"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        form = URI.decode_query(body)

        assert form["client_id"] == "client-id"
        assert form["client_secret"] == "client-secret"
        assert form["code"] == "code-123"
        assert form["redirect_uri"] == "https://example.test/oauth"
        assert form["grant_type"] == "authorization_code"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "access_token" => "access-token",
            "refresh_token" => "refresh-token",
            "expires_in" => 3600
          })
        )
      end)

      assert {:ok, %{"access_token" => "access-token", "refresh_token" => "refresh-token"}} =
               Client.exchange_code(
                 %{
                   client_id: "client-id",
                   client_secret: "client-secret",
                   code: "code-123",
                   redirect_uri: "https://example.test/oauth",
                   plug: {Req.Test, YouTubeClientMock}
                 },
                 plug: {Req.Test, YouTubeClientMock}
               )
    end

    test "reports missing OAuth fields" do
      assert {:error, {:missing_oauth_fields, ["client_secret", "code", "redirect_uri"]}} =
               Client.exchange_code(%{client_id: "client-id"})
    end
  end

  describe "request/3" do
    test "uses explicit runtime access token and atom-key params" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer runtime-token"]

        query = URI.decode_query(conn.query_string)
        assert query["part"] == "snippet,statistics"
        assert query["id"] == "channel-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, %{"items" => []}} =
               Client.request(:get, "/channels", %{
                 access_token: "runtime-token",
                 params: %{part: "snippet,statistics", id: "channel-1"},
                 plug: {Req.Test, YouTubeClientMock}
               })
    end

    test "does not silently call the API without a token" do
      assert {:error, :missing_access_token} = Client.request(:get, "/channels")
    end

    test "normalizes quota errors" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{
              "message" => "Quota exceeded",
              "errors" => [%{"reason" => "quotaExceeded"}]
            }
          })
        )
      end)

      assert {:error, {:youtube, :quota_exceeded, 403, "Quota exceeded"}} =
               Client.request(:get, "/channels", %{
                 access_token: "runtime-token",
                 plug: {Req.Test, YouTubeClientMock}
               })
    end
  end

  describe "start_resumable_upload/2" do
    test "returns the upload session URL" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer runtime-token"]
        assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]

        query = URI.decode_query(conn.query_string)
        assert query["uploadType"] == "resumable"
        assert query["part"] == "snippet,status"

        conn
        |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session/1")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{session_url: "https://upload.youtube.test/session/1"}} =
               Client.start_resumable_upload(
                 %{snippet: %{title: "Demo"}, status: %{privacyStatus: "private"}},
                 %{
                   access_token: "runtime-token",
                   content_type: "video/mp4",
                   plug: {Req.Test, YouTubeClientMock}
                 }
               )
    end

    test "fails clearly when YouTube omits Location" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:error, :missing_upload_location} =
               Client.start_resumable_upload(%{snippet: %{title: "Demo"}}, %{
                 access_token: "runtime-token",
                 plug: {Req.Test, YouTubeClientMock}
               })
    end
  end

  describe "resumable upload sessions" do
    test "completes an upload session with bytes and runtime auth" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/session/1"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer runtime-token"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["video/mp4"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "video-bytes"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "video-1"}))
      end)

      assert {:ok, %{"id" => "video-1"}} =
               Client.complete_resumable_upload(
                 "https://upload.youtube.test/session/1",
                 "video-bytes",
                 %{
                   access_token: "runtime-token",
                   content_type: "video/mp4",
                   plug: {Req.Test, YouTubeClientMock}
                 }
               )
    end

    test "reports upload progress from a 308 status response" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/session/1"
        assert Plug.Conn.get_req_header(conn, "content-range") == ["bytes */123"]

        conn
        |> Plug.Conn.put_resp_header("range", "bytes=0-42")
        |> Plug.Conn.send_resp(308, "")
      end)

      assert {:ok, %{status: :in_progress, committed_range: "bytes=0-42"}} =
               Client.upload_status("https://upload.youtube.test/session/1", %{
                 total_size: 123,
                 plug: {Req.Test, YouTubeClientMock}
               })
    end
  end
end
