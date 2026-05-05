defmodule Lux.Lenses.YouTube.Search.SearchVideosTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Search.SearchVideos

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "searches videos by query" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/search"
      query = URI.decode_query(conn.query_string)
      assert query["q"] == "lux agents"
      assert query["type"] == "video"
      assert query["part"] == "snippet"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "nextPageToken" => "next-search",
          "items" => [
            %{
              "id" => %{"videoId" => "video-1"},
              "snippet" => %{
                "title" => "Lux agents demo",
                "channelId" => "UC_test",
                "channelTitle" => "Lux Channel",
                "publishedAt" => "2026-01-01T00:00:00Z"
              }
            }
          ]
        })
      )
    end)

    assert {:ok,
            %{
              videos: [%{video_id: "video-1", title: "Lux agents demo"}],
              next_page_token: "next-search"
            }} =
             SearchVideos.focus(%{query: "lux agents"}, %{})
  end
end
