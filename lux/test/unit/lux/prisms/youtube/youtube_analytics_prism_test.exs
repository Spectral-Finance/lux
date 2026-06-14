defmodule Lux.Prisms.YouTube.YouTubeAnalyticsPrismTest do
  use UnitCase, async: true
  alias Lux.Prisms.YouTube.YouTubeAnalyticsPrism

  @moduletag :unit

  setup do
    System.put_env("YOUTUBE_API_KEY", "test_api_key")
    :ok
  end

  test "channel_stats returns success" do
    Req.Test.stub(YouTubeAnalyticsPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "UC123",
          "snippet" => %{"title" => "Test Channel", "description" => "Test"},
          "statistics" => %{
            "subscriberCount" => "10000",
            "viewCount" => "500000",
            "videoCount" => "100"
          }
        }]
      })
    end)
    {:ok, result} = YouTubeAnalyticsPrism.handler(%{action: "channel_stats"}, %{})
    assert result.status == "success"
    assert result.stats.subscribers == "10000"
    assert result.stats.total_views == "500000"
  end

  test "video_stats returns success" do
    Req.Test.stub(YouTubeAnalyticsPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "abc123",
          "snippet" => %{"title" => "Test Video", "publishedAt" => "2026-01-01T00:00:00Z"},
          "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "10"}
        }]
      })
    end)
    {:ok, result} = YouTubeAnalyticsPrism.handler(%{action: "video_stats", video_id: "abc123"}, %{})
    assert result.status == "success"
    assert result.stats.views == "1000"
    assert result.stats.likes == "50"
  end

  test "top_videos returns list" do
    Req.Test.stub(YouTubeAnalyticsPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [
          %{"id" => "v1", "snippet" => %{"title" => "Video 1"}, "statistics" => %{"viewCount" => "9000", "likeCount" => "900"}},
          %{"id" => "v2", "snippet" => %{"title" => "Video 2"}, "statistics" => %{"viewCount" => "5000", "likeCount" => "500"}}
        ]
      })
    end)
    {:ok, result} = YouTubeAnalyticsPrism.handler(%{action: "top_videos", max_results: 2}, %{})
    assert result.status == "success"
    assert length(result.videos) == 2
  end

  test "missing api key returns error" do
    System.delete_env("YOUTUBE_API_KEY")
    result = YouTubeAnalyticsPrism.handler(%{action: "channel_stats"}, %{})
    assert {:error, _} = result
  end
end
