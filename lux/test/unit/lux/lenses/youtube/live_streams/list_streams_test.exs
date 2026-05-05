defmodule Lux.Lenses.YouTube.LiveStreams.ListStreamsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.LiveStreams.ListStreams

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists live streams with pagination and ingestion details" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveStreams"
      query = URI.decode_query(conn.query_string)
      assert query["mine"] == "true"
      assert query["maxResults"] == "5"
      assert query["part"] == "snippet,cdn,status"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "nextPageToken" => "next-streams",
          "pageInfo" => %{"totalResults" => 1, "resultsPerPage" => 5},
          "items" => [
            %{
              "id" => "stream-1",
              "snippet" => %{"title" => "Primary stream", "description" => "RTMP input"},
              "cdn" => %{
                "ingestionType" => "rtmp",
                "resolution" => "1080p",
                "frameRate" => "60fps",
                "ingestionInfo" => %{
                  "ingestionAddress" => "rtmp://example/live",
                  "streamName" => "stream-key"
                }
              },
              "status" => %{"streamStatus" => "ready", "healthStatus" => %{"status" => "good"}}
            }
          ]
        })
      )
    end)

    assert {:ok, %{streams: [stream], next_page_token: "next-streams"}} =
             ListStreams.focus(%{mine: true, max_results: 5}, %{})

    assert stream.id == "stream-1"
    assert stream.ingestion_type == "rtmp"
    assert stream.stream_name == "stream-key"
    assert stream.health_status == "good"
  end

  test "returns an empty streams list" do
    Req.Test.expect(Lux.Lens, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
    end)

    assert {:ok, %{streams: []}} = ListStreams.focus(%{mine: true}, %{})
  end
end
