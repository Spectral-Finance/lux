defmodule Lux.Lenses.YouTube.Live.StreamHealthTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Live.StreamHealth

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "returns normalized health and readiness status" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveStreams"

      query = URI.decode_query(conn.query_string)
      assert query["id"] == "stream-1"
      assert query["part"] == "snippet,cdn,status"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [
            %{
              "id" => "stream-1",
              "snippet" => %{"title" => "Primary ingest"},
              "cdn" => %{
                "ingestionType" => "rtmp",
                "resolution" => "1080p",
                "frameRate" => "30fps"
              },
              "status" => %{
                "streamStatus" => "active",
                "healthStatus" => %{"status" => "good", "configurationIssues" => []}
              }
            }
          ]
        })
      )
    end)

    assert {:ok, [stream]} = StreamHealth.focus(%{id: "stream-1"})
    assert stream.stream_status == "active"
    assert stream.health_status == "good"
    assert stream.ready_for_live == true
  end
end
