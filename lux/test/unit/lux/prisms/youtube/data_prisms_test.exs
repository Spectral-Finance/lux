defmodule Lux.Prisms.YouTube.DataPrismsTest do
  @moduledoc """
  Unit tests for the YouTube Data API prisms added in lux issue #73
  ("YouTube Prism implementation"): VideoStats, ChannelStats, SearchResults,
  Engagement, Keywords, PlaylistItems, and the shared DataUtil helpers.

  All tests are pure and offline — no network, no sockets. Each prism receives
  a raw YouTube Data API v3 resource shape (as returned by videos.list /
  channels.list / search.list / playlistItems.list) and must return a typed,
  normalised record.
  """
  use ExUnit.Case, async: true

  alias Lux.Prisms.YouTube.VideoStats
  alias Lux.Prisms.YouTube.ChannelStats
  alias Lux.Prisms.YouTube.SearchResults
  alias Lux.Prisms.YouTube.Engagement
  alias Lux.Prisms.YouTube.Keywords
  alias Lux.Prisms.YouTube.PlaylistItems
  alias Lux.Prisms.YouTube.DataUtil

  # ---------------------------------------------------------------------------
  # DataUtil
  # ---------------------------------------------------------------------------

  describe "DataUtil.to_int/1" do
    test "coerces YouTube string counts" do
      assert DataUtil.to_int("1234") == 1234
      assert DataUtil.to_int("0") == 0
    end

    test "passes integers through and guards negatives" do
      assert DataUtil.to_int(42) == 42
      assert DataUtil.to_int(-5) == 0
    end

    test "nil and garbage fall back to 0" do
      assert DataUtil.to_int(nil) == 0
      assert DataUtil.to_int("not-a-number") == 0
      assert DataUtil.to_int("") == 0
    end
  end

  describe "DataUtil.iso8601_to_seconds/1" do
    test "parses hours/minutes/seconds" do
      assert DataUtil.iso8601_to_seconds("PT1H2M3S") == 3723
    end

    test "parses minutes and seconds only" do
      assert DataUtil.iso8601_to_seconds("PT2M30S") == 150
    end

    test "parses seconds only" do
      assert DataUtil.iso8601_to_seconds("PT45S") == 45
    end

    test "parses hours only" do
      assert DataUtil.iso8601_to_seconds("PT2H") == 7200
    end

    test "nil and malformed return 0" do
      assert DataUtil.iso8601_to_seconds(nil) == 0
      assert DataUtil.iso8601_to_seconds("") == 0
      assert DataUtil.iso8601_to_seconds("garbage") == 0
    end
  end

  describe "DataUtil.safe_div/2 and round_to/2" do
    test "safe_div guards zero denominator" do
      assert DataUtil.safe_div(10, 0) == 0.0
      assert DataUtil.safe_div(10, 4) == 2.5
    end

    test "round_to rounds to N places" do
      assert DataUtil.round_to(3.14159, 2) == 3.14
      assert DataUtil.round_to(0.123456, 4) == 0.1235
    end
  end

  describe "DataUtil.keywords/2" do
    test "extracts and ranks keywords, dropping stopwords" do
      kws = DataUtil.keywords("elixir elixir liveview tutorial", 10)
      assert hd(kws).keyword == "elixir"
      assert hd(kws).count == 2
    end

    test "respects the limit" do
      kws = DataUtil.keywords("one two three four five six", 3)
      assert length(kws) == 3
    end

    test "empty text yields no keywords" do
      assert DataUtil.keywords("", 10) == []
    end
  end

  # ---------------------------------------------------------------------------
  # VideoStats
  # ---------------------------------------------------------------------------

  describe "VideoStats.handler/2" do
    test "normalises a full videos.list resource" do
      video = %{
        id: "abc",
        snippet: %{title: "Hi", channelTitle: "Chan", publishedAt: "2024-03-01T12:00:00Z"},
        statistics: %{viewCount: "1000", likeCount: "100", commentCount: "10"},
        contentDetails: %{duration: "PT1H2M3S"}
      }

      assert {:ok, r} = VideoStats.handler(video, %{})
      assert r.video_id == "abc"
      assert r.title == "Hi"
      assert r.channel_title == "Chan"
      assert r.view_count == 1000
      assert r.like_count == 100
      assert r.comment_count == 10
      assert r.like_ratio == 0.1
      assert r.comment_ratio == 0.01
      assert r.duration_seconds == 3723
      assert r.published_year == 2024
    end

    test "zero views yields zero ratios (no crash)" do
      video = %{id: "z", statistics: %{viewCount: "0", likeCount: "0", commentCount: "0"}}
      assert {:ok, r} = VideoStats.handler(video, %{})
      assert r.like_ratio == 0.0
      assert r.comment_ratio == 0.0
    end

    test "handles missing fields gracefully" do
      assert {:ok, r} = VideoStats.handler(%{id: "x"}, %{})
      assert r.view_count == 0
      assert r.title == ""
      assert r.published_year == 0
    end
  end

  # ---------------------------------------------------------------------------
  # ChannelStats
  # ---------------------------------------------------------------------------

  describe "ChannelStats.handler/2" do
    test "normalises a full channels.list resource" do
      channel = %{
        id: "UC1",
        snippet: %{title: "My Channel", customUrl: "@mychan", publishedAt: "2015-06-01T00:00:00Z"},
        statistics: %{subscriberCount: "1000", viewCount: "50000", videoCount: "20"},
        contentDetails: %{relatedPlaylists: %{uploads: "UU1"}}
      }

      assert {:ok, r} = ChannelStats.handler(channel, %{})
      assert r.channel_id == "UC1"
      assert r.title == "My Channel"
      assert r.custom_url == "@mychan"
      assert r.subscriber_count == 1000
      assert r.view_count == 50000
      assert r.video_count == 20
      assert r.uploads_playlist_id == "UU1"
      assert r.avg_views_per_video == 2500.0
      assert r.published_year == 2015
    end

    test "zero videos yields zero average (no crash)" do
      channel = %{id: "UC2", statistics: %{subscriberCount: "5", viewCount: "0", videoCount: "0"}}
      assert {:ok, r} = ChannelStats.handler(channel, %{})
      assert r.avg_views_per_video == 0.0
    end

    test "handles missing contentDetails" do
      assert {:ok, r} = ChannelStats.handler(%{id: "UC3"}, %{})
      assert r.uploads_playlist_id == ""
      assert r.subscriber_count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # SearchResults
  # ---------------------------------------------------------------------------

  describe "SearchResults.handler/2" do
    test "flattens video and channel hits with a per-kind breakdown" do
      items = [
        %{
          id: %{kind: "youtube#video", videoId: "v1"},
          snippet: %{title: "A", publishedAt: "2024-01-01T00:00:00Z", channelTitle: "C"}
        },
        %{
          id: %{kind: "youtube#channel", channelId: "UC9"},
          snippet: %{title: "Chan", description: "desc"}
        }
      ]

      assert {:ok, r} = SearchResults.handler(%{items: items}, %{})
      assert r.count == 2
      assert r.by_kind.video == 1
      assert r.by_kind.channel == 1

      video = Enum.find(r.results, &(&1.kind == :video))
      assert video.id == "v1"
      assert video.title == "A"
      assert video.channel_title == "C"
    end

    test "empty items yields zero count" do
      assert {:ok, r} = SearchResults.handler(%{items: []}, %{})
      assert r.count == 0
      assert r.results == []
    end

    test "unknown kinds collapse to :unknown" do
      items = [%{id: %{kind: "youtube#mystery", videoId: "x"}, snippet: %{title: "t"}}]
      assert {:ok, r} = SearchResults.handler(%{items: items}, %{})
      assert hd(r.results).kind == :unknown
    end
  end

  # ---------------------------------------------------------------------------
  # Engagement
  # ---------------------------------------------------------------------------

  describe "Engagement.handler/2" do
    test "computes engagement rate and ranks videos" do
      videos = [
        %{video_id: "a", view_count: 1000, like_count: 100, comment_count: 10},
        %{video_id: "b", view_count: 500, like_count: 10, comment_count: 0}
      ]

      assert {:ok, r} = Engagement.handler(%{videos: videos}, %{})
      assert r.count == 2
      # a: (100+10)/1000*100 = 11.0 ; b: (10+0)/500*100 = 2.0 ; mean = 6.5
      assert r.top.video_id == "a"
      assert r.top.engagement_rate_percent == 11.0
      assert r.average_engagement_rate == 6.5
      assert r.total_views == 1500
    end

    test "zero-view videos are safe" do
      videos = [%{video_id: "z", view_count: 0, like_count: 0, comment_count: 0}]
      assert {:ok, r} = Engagement.handler(%{videos: videos}, %{})
      assert r.count == 1
      assert r.top.engagement_rate_percent == 0.0
    end

    test "empty list yields zeroed summary" do
      assert {:ok, r} = Engagement.handler(%{videos: []}, %{})
      assert r.count == 0
      assert r.average_engagement_rate == 0.0
      assert r.total_views == 0
    end

    test "accepts raw camelCase statistics keys" do
      videos = [%{videoId: "r", viewCount: "200", likeCount: "20", commentCount: "0"}]
      assert {:ok, r} = Engagement.handler(%{videos: videos}, %{})
      assert r.top.engagement_rate_percent == 10.0
    end
  end

  # ---------------------------------------------------------------------------
  # Keywords
  # ---------------------------------------------------------------------------

  describe "Keywords.handler/2" do
    test "extracts ranked keywords from a single title" do
      assert {:ok, r} = Keywords.handler(%{title: "elixir liveview tutorial"}, %{})
      assert r.count == 1
      assert r.unique == 3
      assert Enum.map(r.keywords, & &1.keyword) == ["elixir", "liveview", "tutorial"]
    end

    test "aggregates frequency across a batch of titles" do
      titles = ["elixir tutorial one", "elixir tutorial two", "elixir liveview"]
      assert {:ok, r} = Keywords.handler(%{titles: titles}, %{})
      assert r.count == 3
      assert hd(r.keywords).keyword == "elixir"
      assert hd(r.keywords).count == 3
    end

    test "respects the limit option" do
      assert {:ok, r} = Keywords.handler(%{title: "one two three four five", limit: 2}, %{})
      assert length(r.keywords) == 2
    end

    test "empty input yields no keywords" do
      assert {:ok, r} = Keywords.handler(%{}, %{})
      assert r.count == 0
      assert r.keywords == []
    end
  end

  # ---------------------------------------------------------------------------
  # PlaylistItems
  # ---------------------------------------------------------------------------

  describe "PlaylistItems.handler/2" do
    test "normalises and orders entries by position" do
      items = [
        %{snippet: %{title: "Second", position: 1, resourceId: %{videoId: "v2"}}},
        %{snippet: %{title: "First", position: 0, resourceId: %{videoId: "v1"}}}
      ]

      assert {:ok, r} = PlaylistItems.handler(%{items: items}, %{})
      assert r.count == 2
      assert Enum.map(r.entries, & &1.video_id) == ["v1", "v2"]
      assert r.first_position == 0
      assert r.last_position == 1
    end

    test "empty items yields zero count" do
      assert {:ok, r} = PlaylistItems.handler(%{items: []}, %{})
      assert r.count == 0
      assert r.entries == []
      assert r.first_position == 0
      assert r.last_position == 0
    end

    test "handles missing resourceId" do
      items = [%{snippet: %{title: "No video", position: 0}}]
      assert {:ok, r} = PlaylistItems.handler(%{items: items}, %{})
      assert hd(r.entries).video_id == ""
    end
  end

  # ---------------------------------------------------------------------------
  # Prism contract: every module is a real Lux.Prism with a view/0
  # ---------------------------------------------------------------------------

  describe "Prism contract" do
    for mod <- [VideoStats, ChannelStats, SearchResults, Engagement, Keywords, PlaylistItems] do
      test "#{inspect(mod)} exposes a view/0 with name and schemas" do
        view = unquote(mod).view()
        assert is_binary(view.name)
        assert is_map(view.input_schema)
        assert is_map(view.output_schema)
        assert is_function(view.handler)
      end
    end
  end
end
