defmodule Lux.Prisms.YouTube.Videos.ResumableUploadSessionTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Videos.CompleteResumableUpload
  alias Lux.Prisms.YouTube.Videos.GetUploadStatus

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "completes a resumable upload from runtime invocation input" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "PUT"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer runtime-token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == "video-bytes"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "video-1"}))
    end)

    assert {:ok, %{"id" => "video-1"}} =
             CompleteResumableUpload.handler(
               %{
                 "access_token" => "runtime-token",
                 "session_url" => "https://upload.youtube.test/session/1",
                 "video_bytes" => "video-bytes",
                 "plug" => {Req.Test, YouTubeClientMock}
               },
               %{name: "TestAgent"}
             )
  end

  test "checks resumable upload progress from runtime invocation input" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "PUT"
      assert Plug.Conn.get_req_header(conn, "content-range") == ["bytes */123"]

      conn
      |> Plug.Conn.put_resp_header("range", "bytes=0-42")
      |> Plug.Conn.send_resp(308, "")
    end)

    assert {:ok, %{status: :in_progress, committed_range: "bytes=0-42"}} =
             GetUploadStatus.handler(
               %{
                 "session_url" => "https://upload.youtube.test/session/1",
                 "total_size" => 123,
                 "plug" => {Req.Test, YouTubeClientMock}
               },
               %{name: "TestAgent"}
             )
  end
end
