defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "sends bearer authenticated Data API requests with query params" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]

        query = URI.decode_query(conn.query_string)
        assert query["part"] == "snippet,status"
        assert query["id"] == "video-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, %{"items" => []}} =
               Client.request(:get, "/videos", %{
                 params: %{part: "snippet,status", id: "video-123"}
               })
    end

    test "returns clear YouTube API errors" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"code" => 403, "message" => "insufficient permissions"}
        }))
      end)

      assert {:error, {403, "insufficient permissions"}} =
               Client.request(:post, "/liveBroadcasts", %{json: %{}})
    end

    test "starts resumable uploads and exposes the upload URL" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]
        assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]
        assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["1024"]

        query = URI.decode_query(conn.query_string)
        assert query["uploadType"] == "resumable"
        assert query["part"] == "snippet,status"

        conn
        |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session/abc")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, %{"upload_url" => "https://upload.youtube.test/session/abc"}} =
               Client.request(:post, "/videos", %{
                 endpoint: :upload,
                 params: %{uploadType: "resumable", part: "snippet,status"},
                 headers: [
                   {"X-Upload-Content-Type", "video/mp4"},
                   {"X-Upload-Content-Length", "1024"}
                 ],
                 json: %{snippet: %{title: "Demo"}}
               })
    end
  end
end
