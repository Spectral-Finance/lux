defmodule Lux.Prisms.YouTube.Videos.InsertVideoTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.Videos.InsertVideo

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "starts a resumable video upload session with metadata" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/upload/youtube/v3/videos"
      query = URI.decode_query(conn.query_string)
      assert query["uploadType"] == "resumable"
      assert query["part"] == "snippet,status"
      assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]
      assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["2048"]

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["snippet"]["title"] == "Demo Video"
      assert decoded["status"]["privacyStatus"] == "private"

      conn
      |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session/video-1")
      |> Plug.Conn.send_resp(200, "")
    end)

    assert {:ok, %{upload_url: "https://upload.youtube.test/session/video-1", resumable: true}} =
             InsertVideo.handler(%{
               title: "Demo Video",
               description: "Demo description",
               privacy_status: "private",
               mime_type: "video/mp4",
               content_length: 2048
             }, %{name: "Agent"})
  end
end
