defmodule Lux.Prisms.YouTube.AnalyzeVideoTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.AnalyzeVideo

  test "computes engagement metrics from a videos.list item" do
    params = %{
      id: "abc123",
      snippet: %{"title" => "My Video", "publishedAt" => "2026-01-01T12:00:00Z"},
      statistics: %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "10"},
      contentDetails: %{"duration" => "PT1H2M3S"}
    }

    assert {:ok, r} = AnalyzeVideo.handler(params, %{name: "Agent"})
    assert r.video_id == "abc123"
    assert r.title == "My Video"
    assert r.views == 1000
    assert r.likes == 50
    assert r.comments == 10
    assert_in_delta r.engagement_rate, 0.06, 0.0001
    assert_in_delta r.like_ratio, 0.05, 0.0001
    assert_in_delta r.comment_ratio, 0.01, 0.0001
    assert_in_delta r.duration_seconds, 3723.0, 0.1
    assert r.published_at == "2026-01-01T12:00:00Z"
  end

  test "handles zero views without dividing by zero" do
    params = %{id: "z", statistics: %{"viewCount" => "0"}}
    assert {:ok, r} = AnalyzeVideo.handler(params, %{})
    assert r.views == 0
    assert r.engagement_rate == 0.0
    assert r.engagement_score == 0.0
  end

  test "handles missing statistics gracefully" do
    params = %{id: "m"}
    assert {:ok, r} = AnalyzeVideo.handler(params, %{})
    assert r.views == 0
    assert r.likes == 0
    assert r.duration_seconds == 0.0
  end
end