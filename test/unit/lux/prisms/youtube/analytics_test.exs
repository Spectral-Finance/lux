defmodule Lux.Prisms.YouTube.AnalyticsUtilTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.AnalyticsUtil

  describe "count coercion" do
    test "coerces string counts from videos.list payloads" do
      assert AnalyticsUtil.to_int("1000") == 1000
      assert AnalyticsUtil.to_int("0") == 0
      assert AnalyticsUtil.to_int(nil) == 0
      assert AnalyticsUtil.to_int(42) == 42
      assert AnalyticsUtil.to_int(42.9) == 42
      assert AnalyticsUtil.to_int("not a number") == 0
      assert AnalyticsUtil.to_int(-5) == 0
    end

    test "coerces floats" do
      assert AnalyticsUtil.to_float("3.14") == 3.14
      assert AnalyticsUtil.to_float(7) == 7.0
      assert AnalyticsUtil.to_float(nil) == 0.0
      assert AnalyticsUtil.to_float("bad") == 0.0
    end
  end

  describe "descriptive statistics" do
    test "mean of a list" do
      assert AnalyticsUtil.mean([1, 2, 3, 4]) == 2.5
      assert AnalyticsUtil.mean([]) == 0.0
    end

    test "median of odd and even length lists" do
      assert AnalyticsUtil.median([3, 1, 2]) == 2.0
      assert AnalyticsUtil.median([4, 1, 3, 2]) == 2.5
      assert AnalyticsUtil.median([]) == 0.0
      assert AnalyticsUtil.median([5]) == 5.0
    end

    test "population stdev" do
      assert_in_delta AnalyticsUtil.stdev([2, 4, 4, 4, 5, 5, 7, 9]), 2.0, 0.0001
      assert AnalyticsUtil.stdev([5]) == 0.0
      assert AnalyticsUtil.stdev([]) == 0.0
    end

    test "percentile with linear interpolation" do
      assert_in_delta AnalyticsUtil.percentile([1, 2, 3, 4], 0.5), 2.5, 0.0001
      assert_in_delta AnalyticsUtil.percentile([1, 2, 3, 4], 0.0), 1.0, 0.0001
      assert_in_delta AnalyticsUtil.percentile([1, 2, 3, 4], 1.0), 4.0, 0.0001
      assert AnalyticsUtil.percentile([], 0.5) == 0.0
    end

    test "safe_div guards against divide-by-zero" do
      assert AnalyticsUtil.safe_div(10, 0) == 0.0
      assert AnalyticsUtil.safe_div(10, 2) == 5.0
    end

    test "round_to rounds to N places" do
      assert AnalyticsUtil.round_to(3.14159, 2) == 3.14
      assert AnalyticsUtil.round_to(3.14159, 4) == 3.1416
    end
  end

  describe "ISO-8601 duration parsing" do
    test "parses hours, minutes, seconds" do
      assert AnalyticsUtil.parse_duration("PT1H2M3S") == 3723.0
      assert AnalyticsUtil.parse_duration("PT15M33S") == 933.0
      assert AnalyticsUtil.parse_duration("PT45S") == 45.0
      assert AnalyticsUtil.parse_duration("PT10M") == 600.0
      assert AnalyticsUtil.parse_duration("PT1H") == 3600.0
    end

    test "parses day-based durations" do
      assert AnalyticsUtil.parse_duration("P1DT2H") == 93600.0
    end

    test "returns 0.0 for unparseable durations" do
      assert AnalyticsUtil.parse_duration("garbage") == 0.0
      assert AnalyticsUtil.parse_duration(nil) == 0.0
      assert AnalyticsUtil.parse_duration("") == 0.0
    end
  end

  describe "timestamp parsing and age" do
    test "parses ISO-8601 UTC timestamps to epoch" do
      epoch = AnalyticsUtil.parse_timestamp("1970-01-01T00:00:00Z")
      assert epoch == 0
      assert AnalyticsUtil.parse_timestamp("not-a-date") == nil
      assert AnalyticsUtil.parse_timestamp(nil) == nil
    end

    test "computes age in days" do
      # 10 days after epoch.
      now = 10 * 86400
      assert_in_delta AnalyticsUtil.age_days("1970-01-01T00:00:00Z", now), 10.0, 0.0001
      # Unknown timestamp yields 0.0.
      assert AnalyticsUtil.age_days(nil, now) == 0.0
      # Future timestamp clamps to 0.0.
      assert AnalyticsUtil.age_days("1970-01-02T00:00:00Z", 0) == 0.0
    end
  end

  describe "engagement maths" do
    test "engagement rate is (likes + comments) / views" do
      assert_in_delta AnalyticsUtil.engagement_rate(1000, 50, 10), 0.06, 0.0001
      assert AnalyticsUtil.engagement_rate(0, 50, 10) == 0.0
    end

    test "like and comment ratios" do
      assert_in_delta AnalyticsUtil.like_ratio(1000, 50), 0.05, 0.0001
      assert_in_delta AnalyticsUtil.comment_ratio(1000, 10), 0.01, 0.0001
    end

    test "engagement score is bounded 0-100 anchored at 4%" do
      assert_in_delta AnalyticsUtil.engagement_score(0.04), 100.0, 0.0001
      assert_in_delta AnalyticsUtil.engagement_score(0.0), 0.0, 0.0001
      assert_in_delta AnalyticsUtil.engagement_score(0.02), 50.0, 0.0001
      # Saturates above the anchor.
      assert AnalyticsUtil.engagement_score(0.5) == 100.0
    end
  end

  describe "key-agnostic access" do
    test "fetch_key works with atom and string keys" do
      assert AnalyticsUtil.fetch_key(%{"title" => "Hi"}, :title) == "Hi"
      assert AnalyticsUtil.fetch_key(%{title: "Hi"}, "title") == "Hi"
      assert AnalyticsUtil.fetch_key(%{}, :missing) == nil
    end

    test "dig walks nested maps" do
      payload = %{"snippet" => %{"title" => "Nested"}}
      assert AnalyticsUtil.dig(payload, [:snippet, :title]) == "Nested"
      assert AnalyticsUtil.dig(payload, [:snippet, :missing]) == nil
    end
  end

  describe "video normalisation" do
    test "normalises a string-keyed videos.list item" do
      item = %{
        "id" => "v1",
        "snippet" => %{"title" => "How to bake", "publishedAt" => "2026-01-01T00:00:00Z"},
        "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "5"},
        "contentDetails" => %{"duration" => "PT10M"}
      }

      m = AnalyticsUtil.video_metrics(item)
      assert m.id == "v1"
      assert m.title == "How to bake"
      assert m.views == 1000
      assert m.likes == 50
      assert m.comments == 5
      assert m.duration_seconds == 600.0
    end

    test "tolerates missing sections" do
      m = AnalyticsUtil.video_metrics(%{"id" => "v2"})
      assert m.views == 0
      assert m.title == ""
      assert m.duration_seconds == 0.0
    end

    test "enrich adds derived engagement fields" do
      m = AnalyticsUtil.video_metrics(%{
        "id" => "v1",
        "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "10"}
      })

      e = AnalyticsUtil.enrich(m)
      assert_in_delta e.engagement_rate, 0.06, 0.0001
      assert_in_delta e.like_ratio, 0.05, 0.0001
      assert e.engagement_score > 0.0
    end

    test "extracts uploads playlist id" do
      item = %{"contentDetails" => %{"relatedPlaylists" => %{"uploads" => "UU123"}}}
      assert AnalyticsUtil.uploads_playlist(item) == "UU123"
    end

    test "extracts video ids from a playlistItems payload" do
      payload = %{
        "items" => [
          %{"contentDetails" => %{"videoId" => "a"}},
          %{"contentDetails" => %{"videoId" => "b"}},
          %{"contentDetails" => %{}}
        ]
      }

      assert AnalyticsUtil.playlist_video_ids(payload) == ["a", "b"]
    end
  end

  describe "formatting helpers" do
    test "format_duration renders H:MM:SS or M:SS" do
      assert AnalyticsUtil.format_duration(3723) == "1:02:03"
      assert AnalyticsUtil.format_duration(125) == "2:05"
      assert AnalyticsUtil.format_duration(0) == "0:00"
    end

    test "compact renders K/M/B suffixes" do
      assert AnalyticsUtil.compact(1500) == "1.5K"
      assert AnalyticsUtil.compact(2_400_000) == "2.4M"
      assert AnalyticsUtil.compact(3_000_000_000) == "3B"
      assert AnalyticsUtil.compact(999) == "999"
    end
  end
end

defmodule Lux.Prisms.YouTube.ChannelAnalyticsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.ChannelAnalytics

  defp video(id, title, views, likes, comments, published \\ "2026-01-01T00:00:00Z") do
    %{
      "id" => id,
      "snippet" => %{"title" => title, "publishedAt" => published},
      "statistics" => %{
        "viewCount" => Integer.to_string(views),
        "likeCount" => Integer.to_string(likes),
        "commentCount" => Integer.to_string(comments)
      }
    }
  end

  test "aggregates totals and averages across videos" do
    videos = [
      video("v1", "A", 1000, 50, 5),
      video("v2", "B", 2000, 100, 10),
      video("v3", "C", 3000, 150, 15)
    ]

    assert {:ok, r} = ChannelAnalytics.handler(%{videos: videos}, %{})
    assert r.video_count == 3
    assert r.total_views == 6000
    assert r.total_likes == 300
    assert r.total_comments == 30
    assert_in_delta r.avg_views, 2000.0, 0.0001
    assert_in_delta r.median_views, 2000.0, 0.0001
    assert r.engagement_score > 0.0
  end

  test "ranks top videos by views" do
    videos = [video("v1", "Small", 100, 5, 1), video("v2", "Big", 9000, 400, 40)]

    assert {:ok, r} = ChannelAnalytics.handler(%{videos: videos}, %{})
    assert hd(r.top_videos).id == "v2"
    assert length(r.top_videos) == 2
  end

  test "handles an empty catalogue" do
    assert {:ok, r} = ChannelAnalytics.handler(%{videos: []}, %{})
    assert r.video_count == 0
    assert r.total_views == 0
    assert r.engagement_score == 0.0
    assert r.top_videos == []
  end

  test "reports upload cadence from publish dates" do
    videos = [
      video("v1", "A", 100, 5, 1, "2026-01-01T00:00:00Z"),
      video("v2", "B", 200, 8, 2, "2026-01-08T00:00:00Z")
    ]

    assert {:ok, r} = ChannelAnalytics.handler(%{videos: videos}, %{})
    assert String.contains?(r.upload_cadence, "videos")
  end

  test "exposes input/output schema" do
    view = ChannelAnalytics.view()
    assert "videos" in view.input_schema.required
    assert "total_views" in view.output_schema.required
  end
end

defmodule Lux.Prisms.YouTube.VideoPerformanceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.VideoPerformance

  defp video(id, title, views, likes, comments) do
    %{
      "id" => id,
      "snippet" => %{"title" => title, "publishedAt" => "2026-01-01T00:00:00Z"},
      "statistics" => %{
        "viewCount" => Integer.to_string(views),
        "likeCount" => Integer.to_string(likes),
        "commentCount" => Integer.to_string(comments)
      }
    }
  end

  test "scores and ranks videos by performance" do
    videos = [
      video("v1", "Low", 100, 1, 0),
      video("v2", "High", 10000, 900, 100)
    ]

    assert {:ok, r} = VideoPerformance.handler(%{videos: videos, now_epoch: 1_800_000_000}, %{})
    assert r.count == 2
    assert hd(r.ranked).id == "v2"
    assert hd(r.ranked).performance_score >= Enum.at(r.ranked, 1).performance_score
  end

  test "flags breakout outliers above 2x median" do
    videos = [
      video("v1", "A", 100, 5, 1),
      video("v2", "B", 120, 6, 1),
      video("v3", "Hit", 100_000, 5000, 500)
    ]

    assert {:ok, r} = VideoPerformance.handler(%{videos: videos}, %{})
    hit = Enum.find(r.ranked, &(&1.id == "v3"))
    assert hit.outlier == true
  end

  test "handles empty input" do
    assert {:ok, r} = VideoPerformance.handler(%{videos: []}, %{})
    assert r.count == 0
    assert r.ranked == []
  end

  test "exposes schema" do
    view = VideoPerformance.view()
    assert "videos" in view.input_schema.required
    assert "ranked" in view.output_schema.required
  end
end

defmodule Lux.Prisms.YouTube.AudienceEngagementTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.AudienceEngagement

  defp video(id, title, views, likes, comments) do
    %{
      "id" => id,
      "snippet" => %{"title" => title, "publishedAt" => "2026-01-01T00:00:00Z"},
      "statistics" => %{
        "viewCount" => Integer.to_string(views),
        "likeCount" => Integer.to_string(likes),
        "commentCount" => Integer.to_string(comments)
      }
    }
  end

  test "computes engagement distribution stats" do
    videos = [
      video("v1", "A", 1000, 50, 10),
      video("v2", "B", 2000, 120, 20),
      video("v3", "C", 1500, 30, 5)
    ]

    assert {:ok, r} = AudienceEngagement.handler(%{videos: videos}, %{})
    assert r.total_videos == 3
    assert r.avg_engagement_rate > 0.0
    assert r.engagement_stdev >= 0.0
    assert r.health in [:excellent, :healthy, :developing, :at_risk]
  end

  test "identifies most and least engaging videos" do
    videos = [
      video("v1", "Low", 1000, 1, 0),
      video("v2", "High", 1000, 200, 50)
    ]

    assert {:ok, r} = AudienceEngagement.handler(%{videos: videos}, %{})
    assert r.most_engaging.id == "v2"
    assert r.least_engaging.id == "v1"
  end

  test "empty catalogue is at_risk with a diagnostic" do
    assert {:ok, r} = AudienceEngagement.handler(%{videos: []}, %{})
    assert r.total_videos == 0
    assert r.health == :at_risk
    assert length(r.diagnostics) >= 1
  end

  test "exposes schema" do
    view = AudienceEngagement.view()
    assert "videos" in view.input_schema.required
    assert "health" in view.output_schema.required
  end
end

defmodule Lux.Prisms.YouTube.PerformancePredictorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.PerformancePredictor

  defp video(id, title, views, likes, comments, duration) do
    %{
      "id" => id,
      "snippet" => %{"title" => title, "publishedAt" => "2026-01-01T00:00:00Z"},
      "statistics" => %{
        "viewCount" => Integer.to_string(views),
        "likeCount" => Integer.to_string(likes),
        "commentCount" => Integer.to_string(comments)
      },
      "contentDetails" => %{"duration" => duration}
    }
  end

  test "predicts views for a candidate similar to history" do
    history = [
      video("v1", "Sourdough baking guide", 10000, 500, 50, "PT12M"),
      video("v2", "Sourdough baking tips", 12000, 600, 60, "PT11M"),
      video("v3", "Sourdough bread recipe", 9000, 450, 45, "PT13M")
    ]

    candidate = %{title: "Sourdough baking at home", duration_seconds: 720}

    assert {:ok, r} = PerformancePredictor.handler(
             %{history: history, candidate: candidate},
             %{}
           )

    assert r.predicted_views > 0.0
    assert r.confidence >= 0.0 and r.confidence <= 1.0
    assert r.comparable_count >= 1
    assert r.band in [:breakout, :above_average, :average, :underperform]
    assert String.contains?(r.rationale, "views")
  end

  test "falls back to channel average with no title overlap" do
    history = [video("v1", "Completely unrelated", 5000, 100, 10, "PT5M")]

    assert {:ok, r} =
             PerformancePredictor.handler(
               %{history: history, candidate: %{title: "zzz qqq", duration_seconds: 60}},
               %{}
             )

    assert r.predicted_views > 0.0
  end

  test "handles empty history gracefully" do
    assert {:ok, r} =
             PerformancePredictor.handler(
               %{history: [], candidate: %{title: "Anything"}},
               %{}
             )

    assert r.predicted_views == 0.0
    assert r.band == :average
  end

  test "exposes schema" do
    view = PerformancePredictor.view()
    assert "history" in view.input_schema.required
    assert "candidate" in view.input_schema.required
    assert "predicted_views" in view.output_schema.required
  end
end

defmodule Lux.Prisms.YouTube.PostingTimeOptimizerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.PostingTimeOptimizer

  defp video(id, views, published_at) do
    %{
      "id" => id,
      "snippet" => %{"title" => "Video #{id}", "publishedAt" => published_at},
      "statistics" => %{"viewCount" => Integer.to_string(views), "likeCount" => "10", "commentCount" => "1"}
    }
  end

  test "recommends slots from dated videos" do
    videos = [
      video("v1", 5000, "2026-01-06T18:00:00Z"),
      video("v2", 8000, "2026-01-13T18:00:00Z"),
      video("v3", 2000, "2026-01-08T09:00:00Z")
    ]

    assert {:ok, r} = PostingTimeOptimizer.handler(%{videos: videos}, %{})
    assert r.sample_size == 3
    assert length(r.recommendations) >= 1
    assert r.best_slot.day_of_week in ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  end

  test "handles videos without publish dates" do
    videos = [%{"id" => "v1", "snippet" => %{"title" => "No date"}, "statistics" => %{"viewCount" => "100"}}]

    assert {:ok, r} = PostingTimeOptimizer.handler(%{videos: videos}, %{})
    assert r.sample_size == 0
    assert r.recommendations == []
  end

  test "respects top_n" do
    videos =
      for i <- 1..10 do
        video("v#{i}", i * 100, "2026-01-#{String.pad_leading(Integer.to_string(i), 2, "0")}T18:00:00Z")
      end

    assert {:ok, r} = PostingTimeOptimizer.handler(%{videos: videos, top_n: 2}, %{})
    assert length(r.recommendations) <= 2
  end

  test "exposes schema" do
    view = PostingTimeOptimizer.view()
    assert "videos" in view.input_schema.required
    assert "recommendations" in view.output_schema.required
  end
end

defmodule Lux.Prisms.YouTube.ContentRecommendationsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.ContentRecommendations

  defp video(id, title, views, duration) do
    %{
      "id" => id,
      "snippet" => %{"title" => title, "publishedAt" => "2026-01-01T00:00:00Z"},
      "statistics" => %{"viewCount" => Integer.to_string(views), "likeCount" => "10", "commentCount" => "1"},
      "contentDetails" => %{"duration" => duration}
    }
  end

  test "identifies topics to double down on" do
    videos = [
      video("v1", "Sourdough baking guide one", 20000, "PT10M"),
      video("v2", "Sourdough baking guide two", 22000, "PT10M"),
      video("v3", "Unrelated vlog here", 1000, "PT10M"),
      video("v4", "Unrelated vlog there", 1200, "PT10M")
    ]

    assert {:ok, r} = ContentRecommendations.handler(%{videos: videos}, %{})
    assert r.video_count == 4
    keywords = Enum.map(r.double_down, & &1.keyword)
    assert "sourdough" in keywords
  end

  test "recommends an ideal length band" do
    videos = [
      video("v1", "Short clip", 5000, "PT3M"),
      video("v2", "Long deep dive", 15000, "PT25M")
    ]

    assert {:ok, r} = ContentRecommendations.handler(%{videos: videos}, %{})
    assert String.contains?(r.ideal_length, "band")
  end

  test "handles empty catalogue" do
    assert {:ok, r} = ContentRecommendations.handler(%{videos: []}, %{})
    assert r.video_count == 0
    assert r.double_down == []
    assert r.retire == []
  end

  test "exposes schema" do
    view = ContentRecommendations.view()
    assert "videos" in view.input_schema.required
    assert "double_down" in view.output_schema.required
  end
end