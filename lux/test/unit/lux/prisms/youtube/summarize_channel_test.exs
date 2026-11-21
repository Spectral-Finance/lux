defmodule Lux.Prisms.YouTube.SummarizeChannelTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.SummarizeChannel

  test "aggregates per-video metrics" do
    videos = [
      %{video_id: "a", views: 1000, likes: 50, comments: 10, engagement_rate: 0.06},
      %{video_id: "b", views: 500, likes: 10, comments: 2, engagement_rate: 0.024}
    ]

    assert {:ok, r} = SummarizeChannel.handler(%{videos: videos}, %{name: "Agent"})
    assert r.count == 2
    assert r.total_views == 1500
    assert_in_delta r.mean_views, 750.0, 0.01
    assert r.median_views == 750
    assert r.total_likes == 60
    assert r.total_comments == 12
    assert_in_delta r.aggregate_engagement_rate, 0.048, 0.001
    assert r.top_video.video_id == "a"
    assert r.bottom_video.video_id == "b"
  end

  test "empty list returns count 0" do
    assert {:ok, r} = SummarizeChannel.handler(%{videos: []}, %{})
    assert r == %{count: 0}
  end

  test "invalid input returns error" do
    assert {:error, _} = SummarizeChannel.handler(%{}, %{})
  end
end