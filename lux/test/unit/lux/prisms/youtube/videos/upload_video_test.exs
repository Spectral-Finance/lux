defmodule Lux.Prisms.YouTube.Videos.UploadVideoTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.Videos.UploadVideo

  setup do
    Application.put_env(:lux, Lux.Integrations.YouTube.Client,
      plug: {Req.Test, YouTubeClientMock}
    )

    Req.Test.verify_on_exit!()
    :ok
  end

  test "starts a resumable upload session and uploads video bytes" do
    Req.Test.expect(YouTubeClientMock, 2, fn conn ->
      cond do
        conn.method == "POST" ->
          assert conn.request_path == "/upload/youtube/v3/videos"

          assert Plug.Conn.get_req_header(conn, "authorization") == [
                   "Bearer test-youtube-token"
                 ]

          assert Plug.Conn.get_req_header(conn, "x-upload-content-type") == ["video/mp4"]
          assert Plug.Conn.get_req_header(conn, "x-upload-content-length") == ["5"]

          conn
          |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session/abc")
          |> Plug.Conn.send_resp(200, "")

        conn.method == "PUT" ->
          assert conn.request_path == "/session/abc"
          assert Plug.Conn.get_req_header(conn, "content-type") == ["video/mp4"]
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body == <<0, 1, 2, 3, 4>>

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "id" => "video-abc",
              "status" => %{"uploadStatus" => "uploaded"}
            })
          )
      end
    end)

    assert {:ok, %{uploaded: true, video_id: "video-abc", upload_status: "uploaded"}} =
             UploadVideo.handler(
               %{
                 title: "Launch demo",
                 description: "Demo upload",
                 mime_type: "video/mp4",
                 video_data: <<0, 1, 2, 3, 4>>,
                 privacy_status: "private"
               },
               %{}
             )
  end

  test "returns upload initiation errors" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        403,
        Jason.encode!(%{"error" => %{"message" => "Insufficient Permission"}})
      )
    end)

    assert {:error, {403, "Insufficient Permission"}} =
             UploadVideo.handler(%{title: "Launch demo", video_data: <<1, 2, 3>>}, %{})
  end
end
