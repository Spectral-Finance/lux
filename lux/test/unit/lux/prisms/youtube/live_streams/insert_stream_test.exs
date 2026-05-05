defmodule Lux.Prisms.YouTube.LiveStreams.InsertStreamTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveStreams.InsertStream

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates a live stream with quality controls" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveStreams"
      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet,cdn,status"
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["snippet"]["title"] == "Primary 1080p"
      assert decoded["cdn"]["ingestionType"] == "rtmp"
      assert decoded["cdn"]["resolution"] == "1080p"
      assert decoded["cdn"]["frameRate"] == "60fps"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "stream-1", "snippet" => %{"title" => "Primary 1080p"}, "status" => %{"streamStatus" => "created"}, "cdn" => %{"resolution" => "1080p", "frameRate" => "60fps"}}))
    end)

    assert {:ok, %{id: "stream-1", title: "Primary 1080p", stream_status: "created", resolution: "1080p", frame_rate: "60fps"}} =
             InsertStream.handler(%{title: "Primary 1080p", ingestion_type: "rtmp", resolution: "1080p", frame_rate: "60fps"}, %{name: "Agent"})
  end

  test "rejects invalid quality profile before API call" do
    assert {:error, "Invalid resolution. Expected one of: 1080p, 1440p, 240p, 360p, 480p, 720p, variable"} =
             InsertStream.handler(%{title: "Bad", resolution: "12k", frame_rate: "60fps"}, %{name: "Agent"})
  end
end
