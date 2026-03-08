defmodule Lux.Prisms.YouTube.Intelligence.PerformancePredictorTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.Intelligence.PerformancePredictor

  describe "handler/2" do
    test "predicts performance for a video" do
      assert {:ok, result} =
               PerformancePredictor.handler(
                 %{
                   title: "Ultimate Guide to Elixir Programming in 2026",
                   tags: ["elixir", "programming", "functional", "erlang", "beam"],
                   description: String.duplicate("Learn Elixir programming ", 20),
                   duration_minutes: 12,
                   niche: "programming",
                   channel_subscribers: 10_000,
                   channel_avg_views: 2000
                 },
                 []
               )

      assert result.predicted_views.low > 0
      assert result.predicted_views.mid > result.predicted_views.low
      assert result.predicted_views.high > result.predicted_views.mid
      assert result.predicted_engagement.rate > 0
      assert result.confidence > 0
      assert is_list(result.recommendations)
    end

    test "lower confidence without historical data" do
      {:ok, no_history} =
        PerformancePredictor.handler(%{title: "Test Video", channel_subscribers: 100}, [])

      {:ok, with_history} =
        PerformancePredictor.handler(
          %{
            title: "Test Video",
            channel_subscribers: 100,
            historical_videos: Enum.map(1..10, fn _ -> %{views: 100} end)
          },
          []
        )

      assert with_history.confidence > no_history.confidence
    end

    test "scores titles with power words higher" do
      {:ok, plain} = PerformancePredictor.handler(%{title: "Elixir Tutorial"}, [])
      {:ok, power} = PerformancePredictor.handler(%{title: "Ultimate Guide to Elixir - Best Practices Revealed"}, [])

      assert power.scores.title > plain.scores.title
    end

    test "optimal duration gets higher score" do
      {:ok, short} = PerformancePredictor.handler(%{title: "Test", duration_minutes: 1}, [])
      {:ok, optimal} = PerformancePredictor.handler(%{title: "Test", duration_minutes: 10}, [])
      {:ok, long} = PerformancePredictor.handler(%{title: "Test", duration_minutes: 60}, [])

      assert optimal.scores.duration > short.scores.duration
      assert optimal.scores.duration > long.scores.duration
    end

    test "generates recommendations for weak areas" do
      {:ok, result} =
        PerformancePredictor.handler(
          %{title: "x", duration_minutes: 1},
          []
        )

      assert length(result.recommendations) > 0
    end
  end
end
