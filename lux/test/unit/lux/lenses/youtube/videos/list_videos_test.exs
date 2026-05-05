defmodule Lux.Lenses.YouTube.Videos.ListVideosTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Videos.ListVideos

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists videos with pagination parameters" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/videos"
      query = URI.decode_query(conn.query_string)
      assert query["chart"] == "mostPopular"
      assert query["maxResults"] == "2"
      assert query["pageToken"] == "page-1"
      assert query["part"] == "snippet,statistics"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "nextPageToken" => "page-2",
        "pageInfo" => %{"totalResults" => 10, "resultsPerPage" => 2},
        "items" => [%{"id" => "video-1", "snippet" => %{"title" => "Video 1", "channelTitle" => "Lux"}, "statistics" => %{"viewCount" => "42"}}]
      }))
    end)

    assert {:ok, %{next_page_token: "page-2", page_info: %{total_results: 10}, videos: [%{id: "video-1", title: "Video 1", view_count: "42"}]}} =
             ListVideos.focus(%{chart: "mostPopular", max_results: 2, page_token: "page-1"})
  end
end
