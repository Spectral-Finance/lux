defmodule Lux.Prisms.YouTube.UploadVideoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.UploadVideo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "uploads video" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/upload/youtube/v3/videos"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "id" => "vid123",
        "snippet" => %{"title" => "Test"},
        "status" => %{"uploadStatus" => "uploaded", "privacyStatus" => "private"}
      }))
    end)

    assert {:ok, %{video_id: "vid123"}} =
      UploadVideo.handler(%{title: "Test", file_path: "/tmp/a.mp4", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end
end
