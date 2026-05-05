defmodule Lux.Lenses.YouTube.LiveStreams.GetStreamHealthTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.LiveStreams.GetStreamHealth

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches stream health and configuration" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveStreams"
      query = URI.decode_query(conn.query_string)
      assert query["id"] == "stream-123"
      assert query["part"] == "snippet,status,cdn"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "stream-123",
            "snippet" => %{"title" => "Primary Stream"},
            "status" => %{"streamStatus" => "active", "healthStatus" => %{"status" => "good"}},
            "cdn" => %{"ingestionType" => "rtmp", "resolution" => "1080p", "frameRate" => "30fps"}
          }
        ]
      }))
    end)

    assert {:ok, %{id: "stream-123", title: "Primary Stream", stream_status: "active", health_status: "good", ingestion_type: "rtmp", resolution: "1080p", frame_rate: "30fps"}} =
             GetStreamHealth.focus(%{id: "stream-123"})
  end
end
