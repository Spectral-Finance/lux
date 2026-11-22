defmodule Lux.Prisms.YouTube.IntelUtilTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.IntelUtil

  describe "get_field/2 + section/2 (string & atom keys)" do
    test "reads string keys from raw API maps" do
      assert IntelUtil.get_field(%{"viewCount" => "42"}, "viewCount") == "42"
    end

    test "reads atom keys from fixture maps" do
      assert IntelUtil.get_field(%{viewCount: "42"}, "viewCount") == "42"
    end

    test "returns nil for a missing key" do
      assert IntelUtil.get_field(%{}, "nope") == nil
    end

    test "section returns the nested map or empty" do
      assert IntelUtil.section(%{"statistics" => %{"a" => 1}}, "statistics") == %{"a" => 1}
      assert IntelUtil.section(%{}, "statistics") == %{}
      assert IntelUtil.section(%{"statistics" => "oops"}, "statistics") == %{}
    end
  end

  describe "percent/2" do
    test "computes a percentage" do
      assert IntelUtil.percent(50, 200) == 25.0
    end

    test "is zero when the whole is zero" do
      assert IntelUtil.percent(5, 0) == 0.0
    end
  end

  describe "median/1" do
    test "odd length" do
      assert IntelUtil.median([3, 1, 2]) == 2.0
    end

    test "even length averages the middle two" do
      assert IntelUtil.median([4, 1, 3, 2]) == 2.5
    end

    test "empty is zero" do
      assert IntelUtil.median([]) == 0.0
    end
  end

  describe "clamp/3" do
    test "clamps below, above and within" do
      assert IntelUtil.clamp(-5, 0, 10) == 0
      assert IntelUtil.clamp(15, 0, 10) == 10
      assert IntelUtil.clamp(5, 0, 10) == 5
    end
  end

  describe "iso8601_to_seconds/1" do
    test "parses minutes and seconds" do
      assert IntelUtil.iso8601_to_seconds("PT4M13S") == 253
    end

    test "parses hours, minutes and seconds" do
      assert IntelUtil.iso8601_to_seconds("PT1H2M3S") == 3723
    end

    test "parses days" do
      assert IntelUtil.iso8601_to_seconds("P1DT2H") == 93_600
    end

    test "nil and empty are zero" do
      assert IntelUtil.iso8601_to_seconds(nil) == 0
      assert IntelUtil.iso8601_to_seconds("") == 0
    end
  end

  describe "parse_year/1" do
    test "extracts the year from RFC-3339" do
      assert IntelUtil.parse_year("2024-01-15T10:00:00Z") == 2024
    end

    test "nil is zero" do
      assert IntelUtil.parse_year(nil) == 0
    end
  end

  describe "keywords/2" do
    test "ranks content words deterministically" do
      text = "sourdough bread sourdough starter sourdough"
      kw = IntelUtil.keywords(text, 2)
      assert Enum.at(kw, 0) == {"sourdough", 3}
      assert length(kw) == 2
    end

    test "drops stopwords" do
      kw = IntelUtil.keywords("the a an sourdough", 5)
      refute Enum.any?(kw, fn {w, _} -> w in ["the", "a", "an"] end)
    end
  end
end

defmodule Lux.Prisms.YouTube.VideoPerformancePrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.VideoPerformancePrism

  defp video(stats) do
    %{id: "v1", statistics: stats}
  end

  test "computes engagement metrics and a score" do
    v = video(%{"viewCount" => "1000", "likeCount" => "100", "commentCount" => "20"})
    assert {:ok, r} = VideoPerformancePrism.handler(%{video: v}, %{})
    assert r.video_id == "v1"
    assert r.views == 1000
    assert r.likes == 100
    assert r.comments == 20
    assert r.engagement_rate == 12.0
    assert r.like_ratio == 10.0
    assert r.performance_score == 100.0
  end

  test "zero views does not divide by zero" do
    v = video(%{"viewCount" => "0", "likeCount" => "0", "commentCount" => "0"})
    assert {:ok, r} = VideoPerformancePrism.handler(%{video: v}, %{})
    assert r.engagement_rate == 0.0
    assert r.performance_score == 0.0
  end

  test "missing video is handled gracefully (pure prisms never raise)" do
    # Lux.Prism handlers are pure and defensive: a missing :video yields a
    # zeroed result rather than an exception, matching the YouTube prism family.
    assert {:ok, r} = VideoPerformancePrism.handler(%{}, %{})
    assert r.video_id == ""
    assert r.views == 0
    assert r.performance_score == 0.0
  end

  test "low engagement scores below a viral video" do
    low = video(%{"viewCount" => "100000", "likeCount" => "10", "commentCount" => "0"})
    high = video(%{"viewCount" => "1000", "likeCount" => "200", "commentCount" => "20"})
    assert {:ok, lo} = VideoPerformancePrism.handler(%{video: low}, %{})
    assert {:ok, hi} = VideoPerformancePrism.handler(%{video: high}, %{})
    assert hi.performance_score > lo.performance_score
  end
end

defmodule Lux.Prisms.YouTube.VideoMetadataPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.VideoMetadataPrism

  test "flattens a video into indexable metadata" do
    video = %{
      id: "v1",
      snippet: %{
        title: "Intro to Sourdough",
        description: "Learn the basics",
        tags: ["bread", "starter"],
        publishedAt: "2024-01-15T10:00:00Z",
        categoryId: "27",
        channelId: "c1",
        defaultLanguage: "en"
      },
      contentDetails: %{duration: "PT4M13S"}
    }

    assert {:ok, r} = VideoMetadataPrism.handler(%{video: video}, %{})
    assert r.video_id == "v1"
    assert r.title == "Intro to Sourdough"
    assert r.tags == ["bread", "starter"]
    assert r.duration_seconds == 253
    assert r.published_year == 2024
    assert r.category_id == "27"
    assert r.channel_id == "c1"
    assert r.default_language == "en"
  end

  test "missing tags become an empty list" do
    video = %{id: "v2", snippet: %{title: "No tags"}}
    assert {:ok, r} = VideoMetadataPrism.handler(%{video: video}, %{})
    assert r.tags == []
    assert r.duration_seconds == 0
  end
end

defmodule Lux.Prisms.YouTube.ChannelGrowthPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ChannelGrowthPrism

  test "normalises stats and computes a growth signal" do
    channel = %{
      id: "c1",
      snippet: %{title: "My Channel"},
      statistics: %{"subscriberCount" => "1000", "viewCount" => "500000", "videoCount" => "100"}
    }

    assert {:ok, r} = ChannelGrowthPrism.handler(%{channel: channel}, %{})
    assert r.channel_id == "c1"
    assert r.subscribers == 1000
    assert r.subscribers_hidden == false
    assert r.total_views == 500_000
    assert r.video_count == 100
    assert r.avg_views_per_video == 5000.0
    assert r.growth_signal > 0.0
  end

  test "hidden subscriber count is respected" do
    channel = %{
      id: "c2",
      statistics: %{"hiddenSubscriberCount" => "true", "viewCount" => "1000", "videoCount" => "10"}
    }

    assert {:ok, r} = ChannelGrowthPrism.handler(%{channel: channel}, %{})
    assert r.subscribers == 0
    assert r.subscribers_hidden == true
  end
end

defmodule Lux.Prisms.YouTube.ChannelBenchmarkPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ChannelBenchmarkPrism

  test "computes percentile and rank against peers" do
    channel = %{id: "c1", statistics: %{"subscriberCount" => "1000", "viewCount" => "10000"}}
    peers = [
      %{statistics: %{"subscriberCount" => "500", "viewCount" => "5000"}},
      %{statistics: %{"subscriberCount" => "2000", "viewCount" => "20000"}}
    ]

    assert {:ok, r} = ChannelBenchmarkPrism.handler(%{channel: channel, peers: peers}, %{})
    assert r.peer_count == 2
    # beats the 500 peer, loses to the 2000 peer => 1 of 2 => 50th percentile
    assert r.subscriber_percentile == 50.0
    assert r.subscriber_rank == 2
  end

  test "no peers is a full percentile" do
    channel = %{id: "c1", statistics: %{"subscriberCount" => "1000", "viewCount" => "10000"}}
    assert {:ok, r} = ChannelBenchmarkPrism.handler(%{channel: channel, peers: []}, %{})
    assert r.subscriber_percentile == 100.0
    assert r.overall_percentile == 100.0
  end
end

defmodule Lux.Prisms.YouTube.TrendingTopicsPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.TrendingTopicsPrism

  test "extracts view-weighted topics" do
    videos = [
      %{snippet: %{title: "sourdough basics"}, statistics: %{"viewCount" => "1000"}},
      %{snippet: %{title: "sourdough starter"}, statistics: %{"viewCount" => "500"}}
    ]

    assert {:ok, r} = TrendingTopicsPrism.handler(%{videos: videos}, %{})
    assert r.total_videos == 2
    assert {"sourdough", _score} = hd(r.topics)
  end

  test "empty input yields no topics" do
    assert {:ok, r} = TrendingTopicsPrism.handler(%{videos: []}, %{})
    assert r.total_videos == 0
    assert r.topics == []
  end
end

defmodule Lux.Prisms.YouTube.ContentGapPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ContentGapPrism

  test "finds under-covered keywords" do
    # Three competitor videos: "starter", "basics" and "baking" each appear in
    # only 1 of 3 videos (covered by fewer than half the field) => content gaps.
    videos = [
      %{snippet: %{title: "sourdough basics", tags: ["bread", "starter"]}},
      %{snippet: %{title: "sourdough bread", tags: ["bread"]}},
      %{snippet: %{title: "sourdough bread baking", tags: ["bread"]}}
    ]

    assert {:ok, r} = ContentGapPrism.handler(%{videos: videos}, %{})
    assert r.total_videos == 3
    # "starter" appears in only 1 of 3 videos => under-covered => a gap
    assert Enum.any?(r.gaps, fn {word, _} -> word == "starter" end)
    # "sourdough" and "bread" appear in all 3 => NOT gaps
    refute Enum.any?(r.gaps, fn {word, _} -> word in ["sourdough", "bread"] end)
  end

  test "no videos yields no gaps" do
    assert {:ok, r} = ContentGapPrism.handler(%{videos: []}, %{})
    assert r.gaps == []
  end
end

defmodule Lux.Prisms.YouTube.RevenueEstimatePrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.RevenueEstimatePrism

  test "estimates a revenue range from views" do
    assert {:ok, r} = RevenueEstimatePrism.handler(%{views: 100_000}, %{})
    assert r.views == 100_000
    assert r.revenue_low == 100.0
    assert r.revenue_high == 500.0
    assert r.revenue_mid == 300.0
  end

  test "honours a custom RPM band" do
    assert {:ok, r} = RevenueEstimatePrism.handler(%{views: 50_000, rpm_low: 2.0, rpm_high: 4.0}, %{})
    assert r.revenue_low == 100.0
    assert r.revenue_high == 200.0
  end

  test "a swapped band is ordered low<=high" do
    assert {:ok, r} = RevenueEstimatePrism.handler(%{views: 1000, rpm_low: 9.0, rpm_high: 3.0}, %{})
    assert r.rpm_low == 3.0
    assert r.rpm_high == 9.0
  end
end

defmodule Lux.Prisms.YouTube.SeoAuditPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.SeoAuditPrism

  test "a well-optimised video scores high" do
    video = %{
      id: "v1",
      snippet: %{
        title: "Sourdough Starter Guide for Beginners",
        description: String.duplicate("Detailed sourdough starter instructions. ", 10),
        tags: ["sourdough", "bread", "starter", "baking"]
      }
    }

    assert {:ok, r} = SeoAuditPrism.handler(%{video: video, target_keyword: "sourdough"}, %{})
    assert r.seo_score == 100
    assert r.keyword_in_title == true
    assert r.recommendations == []
  end

  test "a poor video scores low with recommendations" do
    video = %{id: "v2", snippet: %{title: "vlog", description: "hi", tags: []}}

    assert {:ok, r} = SeoAuditPrism.handler(%{video: video}, %{})
    assert r.seo_score < 50
    assert length(r.recommendations) > 0
  end

  test "a missing target keyword still scores the keyword signal" do
    video = %{
      id: "v3",
      snippet: %{
        title: "A Reasonably Long Title About Baking",
        description: String.duplicate("content ", 40),
        tags: ["a", "b", "c"]
      }
    }

    assert {:ok, r} = SeoAuditPrism.handler(%{video: video}, %{})
    # no target keyword => keyword signal auto-passes
    assert r.keyword_in_title == false
    refute "Target keyword is missing from the title" in r.recommendations
  end
end

defmodule Lux.Prisms.YouTube.IntelligenceRegistryTest do
  use ExUnit.Case, async: true

  # Every content-intelligence prism must be a well-formed Lux.Prism: it exposes
  # a view/0 struct with a name, description and input/output schemas.
  @prisms [
    Lux.Prisms.YouTube.VideoPerformancePrism,
    Lux.Prisms.YouTube.VideoMetadataPrism,
    Lux.Prisms.YouTube.ChannelGrowthPrism,
    Lux.Prisms.YouTube.ChannelBenchmarkPrism,
    Lux.Prisms.YouTube.TrendingTopicsPrism,
    Lux.Prisms.YouTube.ContentGapPrism,
    Lux.Prisms.YouTube.RevenueEstimatePrism,
    Lux.Prisms.YouTube.SeoAuditPrism
  ]

  test "all eight prisms expose a valid Lux.Prism view" do
    assert length(@prisms) == 8

    Enum.each(@prisms, fn mod ->
      view = mod.view()
      assert is_binary(view.name) and view.name != ""
      assert is_binary(view.description) and view.description != ""
      assert is_map(view.input_schema)
      assert is_map(view.output_schema)
      assert is_function(view.handler, 2)
    end)
  end

  test "prism names are unique" do
    names = Enum.map(@prisms, fn mod -> mod.view().name end)
    assert length(names) == length(Enum.uniq(names))
  end
end