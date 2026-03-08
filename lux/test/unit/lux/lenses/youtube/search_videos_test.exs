defmodule Lux.Lenses.YouTube.SearchVideosTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.SearchVideos

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys, youtube_api_key: "test-key")
    :ok
  end

  test "searches videos" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/search"
      assert conn.query_string =~ "q=elixir"

      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "items" => [
          %{
            "id" => %{"videoId" => "abc123"},
            "snippet" => %{
              "title" => "Elixir Tutorial",
              "description" => "Learn Elixir",
              "channelTitle" => "Elixir Channel",
              "publishedAt" => "2026-01-01T00:00:00Z",
              "thumbnails" => %{"default" => %{"url" => "https://example.com/thumb.jpg"}}
            }
          }
        ]
      }))
    end)

    assert {:ok, %{videos: [video]}} = SearchVideos.focus(%{query: "elixir", plug: {Req.Test, YouTubeClientMock}})
    assert video.id == "abc123"
    assert video.title == "Elixir Tutorial"
  end
end
