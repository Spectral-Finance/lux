defmodule Lux.Lenses.YouTube.AnalyticsTest do
  @moduledoc """
  Test suite for YouTube Analytics lenses.

  These tests verify the lenses' ability to:
  - Fetch and transform channel statistics
  - Fetch and transform video analytics
  - Search for trending content
  - Compare competitor channels
  - Estimate revenue from views

  Tests use Req.Test mocks to simulate API responses without
  requiring actual YouTube API keys.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube
  alias Lux.Lenses.YouTube.ChannelStatsLens
  alias Lux.Lenses.YouTube.VideoAnalyticsLens
  alias Lux.Lenses.YouTube.SearchTrendsLens
  alias Lux.Lenses.YouTube.CompetitorAnalysisLens
  alias Lux.Lenses.YouTube.RevenueEstimatorLens

  require Logger

  setup do
    # Set up YouTube API key for tests
    Application.put_env(:lux, YouTube, api_key: "test-youtube-api-key")
    Req.Test.verify_on_exit!()
    :ok
  end

  # ===================================================================
  # Integration Module Tests
  # ===================================================================

  describe "YouTube integration module" do
    test "base_url returns default URL" do
      assert YouTube.base_url() == "https://www.googleapis.com/youtube/v3"
    end

    test "analytics_base_url returns default URL" do
      assert YouTube.analytics_base_url() == "https://www.googleapis.com/youtubeAnalytics/v2"
    end

    test "headers returns standard headers" do
      headers = YouTube.headers()
      assert {"content-type", "application/json"} in headers
      assert {"accept", "application/json"} in headers
    end

    test "auth returns api_key auth configuration" do
      auth = YouTube.auth()
      assert auth.type == :api_key
      assert is_function(auth.key, 0)
    end

    test "api_key returns configured key" do
      assert YouTube.api_key() == "test-youtube-api-key"
    end

    test "api_key! raises when not configured" do
      Application.delete_env(:lux, YouTube)
      assert_raise RuntimeError, ~r/YouTube API key is not configured/, fn ->
        YouTube.api_key!()
      end
    end

    test "validate_channel_id accepts valid IDs" do
      assert YouTube.validate_channel_id("UC_x5XG1OV2P6uZZ5FSM9Ttw") ==
               {:ok, "UC_x5XG1OV2P6uZZ5FSM9Ttw"}
    end

    test "validate_channel_id rejects invalid IDs" do
      assert YouTube.validate_channel_id("invalid") ==
               {:error, "Invalid YouTube channel ID format. Expected format: UC followed by 22 characters"}
    end

    test "validate_video_id accepts valid IDs" do
      assert YouTube.validate_video_id("dQw4w9WgXcQ") == {:ok, "dQw4w9WgXcQ"}
    end

    test "validate_video_id rejects invalid IDs" do
      assert YouTube.validate_video_id("short") ==
               {:error, "Invalid YouTube video ID format. Expected 11 characters"}
    end

    test "format_date formats Date structs" do
      assert YouTube.format_date(~D[2024-01-15]) == "2024-01-15"
    end

    test "format_date passes through valid date strings" do
      assert YouTube.format_date("2024-01-15") == "2024-01-15"
    end
  end

  # ===================================================================
  # ChannelStatsLens Tests
  # ===================================================================

  describe "ChannelStatsLens" do
    test "successfully fetches channel statistics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.query_string, "part=snippet%2Cstatistics")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "UC_x5XG1OV2P6uZZ5FSM9Ttw",
              "snippet" => %{
                "title" => "Google Developers",
                "description" => "Official Google Developers channel",
                "customUrl" => "@googledevelopers",
                "publishedAt" => "2007-01-01T00:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://example.com/default.jpg"},
                  "medium" => %{"url" => "https://example.com/medium.jpg"},
                  "high" => %{"url" => "https://example.com/high.jpg"}
                }
              },
              "statistics" => %{
                "subscriberCount" => "2500000",
                "viewCount" => "150000000",
                "videoCount" => "1200",
                "hiddenSubscriberCount" => false
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = ChannelStatsLens.focus(%{channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"})
      assert result.channel_id == "UC_x5XG1OV2P6uZZ5FSM9Ttw"
      assert result.title == "Google Developers"
      assert result.statistics.subscriber_count == 2_500_000
      assert result.statistics.view_count == 150_000_000
      assert result.statistics.video_count == 1_200
      assert result.statistics.hidden_subscriber_count == false
    end

    test "handles channel not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => []
        }))
      end)

      assert {:error, message} = ChannelStatsLens.focus(%{channel_id: "UC_INVALID"})
      assert message =~ "No channel found"
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{"message" => "Channel not found"}
        }))
      end)

      assert {:error, "Channel not found"} = ChannelStatsLens.focus(%{channel_id: "UC_INVALID"})
    end

    test "validates schema" do
      lens = ChannelStatsLens.view()
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert Map.has_key?(lens.schema.properties, :part)
      assert lens.schema.properties.part.default == "snippet,statistics"
    end
  end

  # ===================================================================
  # VideoAnalyticsLens Tests
  # ===================================================================

  describe "VideoAnalyticsLens" do
    test "successfully fetches video analytics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.query_string, "part=snippet%2Cstatistics%2CcontentDetails")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "dQw4w9WgXcQ",
              "snippet" => %{
                "title" => "Rick Astley - Never Gonna Give You Up",
                "description" => "Official music video",
                "channelId" => "UC9CuvdOVVMPnGiAb35e6DBA",
                "channelTitle" => "Rick Astley",
                "publishedAt" => "2009-10-25T06:57:23Z",
                "categoryId" => "10",
                "tags" => ["music", "official"],
                "thumbnails" => %{
                  "default" => %{"url" => "https://example.com/default.jpg"},
                  "medium" => %{"url" => "https://example.com/medium.jpg"},
                  "high" => %{"url" => "https://example.com/high.jpg"},
                  "standard" => %{"url" => "https://example.com/standard.jpg"},
                  "maxres" => %{"url" => "https://example.com/maxres.jpg"}
                }
              },
              "statistics" => %{
                "viewCount" => "1500000000",
                "likeCount" => "25000000",
                "commentCount" => "5000000",
                "favoriteCount" => "1000000",
                "dislikeCount" => "500000"
              },
              "contentDetails" => %{
                "duration" => "PT3M33S",
                "dimension" => "2d",
                "definition" => "hd",
                "caption" => "true",
                "licensed" => true
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = VideoAnalyticsLens.focus(%{video_id: "dQw4w9WgXcQ"})
      assert result.video_id == "dQw4w9WgXcQ"
      assert result.title == "Rick Astley - Never Gonna Give You Up"
      assert result.statistics.view_count == 1_500_000_000
      assert result.statistics.like_count == 25_000_000
      assert result.statistics.comment_count == 5_000_000
      assert result.statistics.dislike_count == 500_000
      assert result.channel_title == "Rick Astley"
      assert result.content_details.duration == "PT3M33S"
      assert result.content_details.definition == "hd"
      assert result.content_details.caption == "true"
      assert is_float(result.engagement_rate)
    end

    test "handles video not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => []
        }))
      end)

      assert {:error, message} = VideoAnalyticsLens.focus(%{video_id: "invalid_id"})
      assert message =~ "No video found"
    end

    test "validates schema" do
      lens = VideoAnalyticsLens.view()
      assert Map.has_key?(lens.schema.properties, :video_id)
      assert Map.has_key?(lens.schema.properties, :start_date)
      assert Map.has_key?(lens.schema.properties, :end_date)
      assert Map.has_key?(lens.schema.properties, :metrics)
    end
  end

  # ===================================================================
  # SearchTrendsLens Tests
  # ===================================================================

  describe "SearchTrendsLens" do
    test "successfully searches for trending content" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.query_string, "part=snippet")
        assert String.contains?(conn.query_string, "q=elixir")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"videoId" => "abc123def45"},
              "snippet" => %{
                "title" => "Elixir Programming Tutorial",
                "description" => "Learn Elixir from scratch",
                "channelId" => "UC_CHANNEL_1",
                "channelTitle" => "Code Academy",
                "publishedAt" => "2024-01-15T12:00:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://example.com/thumb1.jpg"},
                  "medium" => %{"url" => "https://example.com/thumb1_m.jpg"},
                  "high" => %{"url" => "https://example.com/thumb1_h.jpg"}
                }
              }
            },
            %{
              "id" => %{"videoId" => "xyz789ghi01"},
              "snippet" => %{
                "title" => "Advanced Elixir Patterns",
                "description" => "Master Elixir OTP",
                "channelId" => "UC_CHANNEL_2",
                "channelTitle" => "Dev Mastery",
                "publishedAt" => "2024-02-20T15:30:00Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://example.com/thumb2.jpg"},
                  "medium" => %{"url" => "https://example.com/thumb2_m.jpg"},
                  "high" => %{"url" => "https://example.com/thumb2_h.jpg"}
                }
              }
            }
          ],
          "nextPageToken" => "CAUQAA",
          "pageInfo" => %{
            "totalResults" => 10000,
            "resultsPerPage" => 10
          },
          "regionCode" => "US"
        }))
      end)

      assert {:ok, result} = SearchTrendsLens.focus(%{
        query: "elixir",
        max_results: 10,
        order: "relevance"
      })

      assert length(result.results) == 2
      assert hd(result.results).video_id == "abc123def45"
      assert hd(result.results).title == "Elixir Programming Tutorial"
      assert hd(result.results).channel_title == "Code Academy"
      assert result.next_page_token == "CAUQAA"
      assert result.total_results == 10_000
    end

    test "handles empty search results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "pageInfo" => %{
            "totalResults" => 0,
            "resultsPerPage" => 10
          }
        }))
      end)

      assert {:ok, result} = SearchTrendsLens.focus(%{query: "nonexistent_query_xyz"})
      assert result.results == []
      assert result.total_results == 0
    end

    test "validates schema" do
      lens = SearchTrendsLens.view()
      assert Map.has_key?(lens.schema.properties, :query)
      assert Map.has_key?(lens.schema.properties, :max_results)
      assert Map.has_key?(lens.schema.properties, :order)
      assert Map.has_key?(lens.schema.properties, :type)
      assert lens.schema.properties.order.enum == ["relevance", "date", "viewCount", "rating", "title"]
    end
  end

  # ===================================================================
  # CompetitorAnalysisLens Tests
  # ===================================================================

  describe "CompetitorAnalysisLens" do
    test "successfully compares multiple channels" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "UC_CHANNEL_A",
              "snippet" => %{
                "title" => "Channel A",
                "description" => "Tech reviews channel",
                "publishedAt" => "2015-01-01T00:00:00Z"
              },
              "statistics" => %{
                "subscriberCount" => "1000000",
                "viewCount" => "50000000",
                "videoCount" => "500",
                "hiddenSubscriberCount" => false
              }
            },
            %{
              "id" => "UC_CHANNEL_B",
              "snippet" => %{
                "title" => "Channel B",
                "description" => "Programming tutorials",
                "publishedAt" => "2018-06-15T00:00:00Z"
              },
              "statistics" => %{
                "subscriberCount" => "2000000",
                "viewCount" => "80000000",
                "videoCount" => "1000",
                "hiddenSubscriberCount" => false
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = CompetitorAnalysisLens.focus(%{
        channel_ids: ["UC_CHANNEL_A", "UC_CHANNEL_B"],
        metrics: ["subscriberCount", "viewCount", "videoCount"]
      })

      assert length(result.channels) == 2
      assert result.comparison.channel_count == 2
      assert result.comparison.total_subscribers == 3_000_000
      assert result.comparison.total_views == 130_000_000
      assert result.comparison.total_videos == 1_500
      assert result.comparison.leader.subscribers == "Channel B"
      assert result.comparison.leader.views == "Channel B"
      assert result.comparison.leader.videos == "Channel B"
      assert length(result.comparison.rankings) == 2
    end

    test "handles single channel response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "UC_CHANNEL_A",
              "snippet" => %{"title" => "Channel A"},
              "statistics" => %{
                "subscriberCount" => "1000000",
                "viewCount" => "50000000",
                "videoCount" => "500"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = CompetitorAnalysisLens.focus(%{
        channel_ids: ["UC_CHANNEL_A"]
      })

      assert length(result.channels) == 1
      assert result.comparison.message =~ "Need at least 2 channels"
    end

    test "validates schema" do
      lens = CompetitorAnalysisLens.view()
      assert Map.has_key?(lens.schema.properties, :channel_ids)
      assert Map.has_key?(lens.schema.properties, :metrics)
      assert Map.has_key?(lens.schema.properties, :include_rankings)
      assert Map.has_key?(lens.schema.properties, :scoring_method)
    end
  end

  # ===================================================================
  # RevenueEstimatorLens Tests
  # ===================================================================

  describe "RevenueEstimatorLens" do
    test "successfully estimates video revenue" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "dQw4w9WgXcQ",
              "snippet" => %{
                "title" => "Rick Astley - Never Gonna Give You Up",
                "channelId" => "UC9CuvdOVVMPnGiAb35e6DBA"
              },
              "statistics" => %{
                "viewCount" => "1500000000"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = RevenueEstimatorLens.focus(%{
        video_id: "dQw4w9WgXcQ",
        cpm_range: %{low: 2.0, high: 5.0},
        niche: "music"
      })

      assert result.video_id == "dQw4w9WgXcQ"
      assert result.view_count == 1_500_000_000
      assert result.monetized_views == 1_125_000_000  # 75% of views
      assert result.revenue_estimate.currency == "USD"
      assert result.revenue_estimate.low > 0
      assert result.revenue_estimate.high > result.revenue_estimate.low
      assert result.revenue_estimate.average > result.revenue_estimate.low
      assert result.cpm_used.niche == "music"
    end

    test "handles video not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => []
        }))
      end)

      assert {:error, message} = RevenueEstimatorLens.focus(%{video_id: "invalid_id"})
      assert message =~ "No video or channel found"
    end

    test "validates schema" do
      lens = RevenueEstimatorLens.view()
      assert Map.has_key?(lens.schema.properties, :video_id)
      assert Map.has_key?(lens.schema.properties, :channel_id)
      assert Map.has_key?(lens.schema.properties, :cpm_range)
      assert Map.has_key?(lens.schema.properties, :niche)
      assert Map.has_key?(lens.schema.properties, :region)
    end

    test "calculates revenue with different niches" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "video123",
              "snippet" => %{"title" => "Finance Video"},
              "statistics" => %{"viewCount" => "1000000"}
            }
          ]
        }))
      end)

      assert {:ok, result} = RevenueEstimatorLens.focus(%{
        video_id: "video123",
        cpm_range: %{low: 5.0, high: 15.0},
        niche: "finance",
        region: "us"
      })

      assert result.revenue_estimate.low > 0
      assert result.revenue_estimate.high > result.revenue_estimate.low
      assert result.cpm_used.region == "us"
    end
  end

  # ===================================================================
  # Lens View Tests
  # ===================================================================

  describe "lens views" do
    test "ChannelStatsLens returns correct view" do
      lens = ChannelStatsLens.view()
      assert lens.name == "YouTube Channel Statistics"
      assert lens.method == :get
      assert String.contains?(lens.url, "youtube/v3/channels")
    end

    test "VideoAnalyticsLens returns correct view" do
      lens = VideoAnalyticsLens.view()
      assert lens.name == "YouTube Video Analytics"
      assert lens.method == :get
      assert String.contains?(lens.url, "youtube/v3/videos")
    end

    test "SearchTrendsLens returns correct view" do
      lens = SearchTrendsLens.view()
      assert lens.name == "YouTube Search Trends"
      assert lens.method == :get
      assert String.contains?(lens.url, "youtube/v3/search")
    end

    test "CompetitorAnalysisLens returns correct view" do
      lens = CompetitorAnalysisLens.view()
      assert lens.name == "YouTube Competitor Analysis"
      assert lens.method == :get
      assert String.contains?(lens.url, "youtube/v3/channels")
    end

    test "RevenueEstimatorLens returns correct view" do
      lens = RevenueEstimatorLens.view()
      assert lens.name == "YouTube Revenue Estimator"
      assert lens.method == :get
      assert String.contains?(lens.url, "youtube/v3/videos")
    end
  end
end
