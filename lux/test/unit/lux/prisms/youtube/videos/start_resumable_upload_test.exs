defmodule Lux.Prisms.YouTube.Videos.StartResumableUploadTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Videos.StartResumableUpload

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "starts a resumable upload session and returns the upload URL" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/upload/youtube/v3/videos"
      assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]
      assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["2048"]

      query = URI.decode_query(conn.query_string)
      assert query["uploadType"] == "resumable"
      assert query["part"] == "snippet,status"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "title"]) == "Demo"
      assert get_in(decoded, ["status", "privacyStatus"]) == "private"

      conn
      |> Plug.Conn.put_resp_header("location", "https://upload.youtube.com/session/xyz")
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
    end)

    assert {:ok, %{upload_url: "https://upload.youtube.com/session/xyz", status: 200}} =
             StartResumableUpload.handler(
               %{
                 title: "Demo",
                 content_type: "video/mp4",
                 content_length: 2048
               },
               %{}
             )
  end

  test "requires a title" do
    assert {:error, "Missing or invalid title"} = StartResumableUpload.handler(%{}, %{})
  end
end
