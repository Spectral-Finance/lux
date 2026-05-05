defmodule Lux.Prisms.YouTube.LiveStreams.UpdateStreamTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.LiveStreams.UpdateStream

  setup do
    Application.put_env(:lux, Lux.Integrations.YouTube.Client,
      plug: {Req.Test, YouTubeClientMock}
    )

    Req.Test.verify_on_exit!()
    :ok
  end

  test "updates live stream metadata and quality controls" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/youtube/v3/liveStreams"

      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet,cdn,status"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["id"] == "stream-789"
      assert decoded["snippet"]["title"] == "Updated stream"
      assert decoded["cdn"]["frameRate"] == "60fps"
      assert decoded["cdn"]["resolution"] == "1080p"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "stream-789",
          "snippet" => %{"title" => "Updated stream"},
          "cdn" => %{"frameRate" => "60fps", "resolution" => "1080p"},
          "status" => %{"streamStatus" => "active"}
        })
      )
    end)

    assert {:ok, %{id: "stream-789", title: "Updated stream", stream_status: "active"}} =
             UpdateStream.handler(
               %{
                 id: "stream-789",
                 title: "Updated stream",
                 frame_rate: "60fps",
                 resolution: "1080p"
               },
               %{}
             )
  end

  test "rejects invalid stream quality updates" do
    assert {:error,
            "Invalid resolution. Expected one of: 1080p, 1440p, 240p, 360p, 480p, 720p, variable"} =
             UpdateStream.handler(%{id: "stream-789", resolution: "16k"}, %{})
  end
end
