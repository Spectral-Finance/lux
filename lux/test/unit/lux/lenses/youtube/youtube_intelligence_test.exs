defmodule Lux.Lenses.YouTube.YouTubeIntelligenceTest do
  @moduledoc """
  Unit tests for YouTube Content Intelligence System, lenses, and metadata optimizer.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.ContentIntelligence
  alias Lux.Lenses.YouTube.Channels.ChannelAudienceLens
  alias Lux.Lenses.YouTube.Discovery.TrendingTopicsLens
  alias Lux.Lenses.YouTube.Videos.VideoAnalyticsLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "ContentIntelligence engagement & metadata engine" do
    test "classifies viral outperformer engagement tier accurately" do
      result =
        ContentIntelligence.analyze_engagement(%{
          view_count: 10_000,
          like_count: 800,
          comment_count: 150
        })

      assert result.like_rate_pct == 8.0
      assert result.comment_rate_pct == 1.5
      assert result.engagement_score > 8.0
      assert result.performance_tier == :viral_outperformer
    end

    test "classifies baseline healthy and needs_optimization tiers" do
      healthy =
        ContentIntelligence.analyze_engagement(%{
          view_count: 10_000,
          like_count: 200,
          comment_count: 10
        })

      low =
        ContentIntelligence.analyze_engagement(%{
          view_count: 10_000,
          like_count: 20,
          comment_count: 1
        })

      assert healthy.performance_tier == :baseline_healthy
      assert low.performance_tier == :needs_optimization
    end

    test "handles zero views without division by zero" do
      zero = ContentIntelligence.analyze_engagement(%{view_count: 0, like_count: 0, comment_count: 0})
      assert zero.like_rate_pct == 0.0
      assert zero.engagement_score == 0.0
      assert zero.performance_tier == :needs_optimization
    end

    test "optimizes short titles, generates SEO tags, description, and thumbnail cues" do
      optimized =
        ContentIntelligence.optimize_metadata(%{
          title: "Elixir GenStage",
          topic: "Elixir GenStage Pipelines",
          tags: ["elixir", "otp"]
        })

      assert String.contains?(optimized.optimized_title, "Elixir GenStage")
      assert String.length(optimized.optimized_title) > String.length("Elixir GenStage")
      assert "elixir" in optimized.recommended_tags
      assert String.contains?(optimized.generated_description, "00:00 Introduction")
      assert length(optimized.thumbnail_recommendations) == 3
    end

    test "scores optimal length titles (45..70 chars) at 95" do
      title = "Building Autonomous Onchain Elixir Agents with Lux Framework"
      optimized = ContentIntelligence.optimize_metadata(%{title: title, topic: "Lux Agents"})

      assert optimized.title_score == 95
      assert optimized.optimized_title == title
    end

    test "predicts optimal posting window from historical performance records" do
      history = [
        %{day_of_week: 1, hour_utc: 12, views_first_24h: 4_500, engagement_score: 3.2},
        %{day_of_week: 4, hour_utc: 16, views_first_24h: 18_200, engagement_score: 6.5},
        %{day_of_week: 6, hour_utc: 20, views_first_24h: 7_100, engagement_score: 4.0}
      ]

      prediction = ContentIntelligence.predict_optimal_posting_time(history)
      assert prediction.day_of_week == 4
      assert prediction.hour_utc == 16
      assert prediction.expected_24h_views == 18_200
      assert prediction.confidence == :moderate
    end

    test "returns default baseline when posting history is empty" do
      prediction = ContentIntelligence.predict_optimal_posting_time([])
      assert prediction.day_of_week == 3
      assert prediction.hour_utc == 15
      assert prediction.confidence == :default_baseline
    end
  end

  describe "VideoAnalyticsLens" do
    test "fetches video metrics and attaches computed engagement intelligence" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "vid_lux_01",
                "snippet" => %{
                  "title" => "Lux Agentic Framework Deep Dive",
                  "channelTitle" => "Spectral Finance",
                  "publishedAt" => "2026-11-01T15:00:00Z",
                  "tags" => ["elixir", "agents", "web3"]
                },
                "statistics" => %{
                  "viewCount" => "50000",
                  "likeCount" => "4200",
                  "commentCount" => "600"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, %{videos: [video], count: 1}} =
               VideoAnalyticsLens.focus(%{"id" => "vid_lux_01"})

      assert video.id == "vid_lux_01"
      assert video.analytics.view_count == 50_000
      assert video.analytics.performance_tier == :viral_outperformer
    end

    test "propagates YouTube API errors on VideoAnalyticsLens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{"code" => 403, "message" => "The request cannot be completed because you have exceeded your quota."}
          })
        )
      end)

      assert {:error, %{"error" => %{"code" => 403}}} =
               VideoAnalyticsLens.focus(%{"id" => "vid_lux_01"})
    end
  end

  describe "ChannelAudienceLens" do
    test "fetches channel statistics and computes avg_views_per_video" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "UC_spectral",
                "snippet" => %{
                  "title" => "Spectral Labs",
                  "description" => "Autonomous Onchain Agents"
                },
                "statistics" => %{
                  "subscriberCount" => "25000",
                  "viewCount" => "1000000",
                  "videoCount" => "40"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, channel} = ChannelAudienceLens.focus(%{"id" => "UC_spectral"})
      assert channel.subscriber_count == 25_000
      assert channel.avg_views_per_video == 25_000.0
    end

    test "returns channel_not_found when items list is empty" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, :channel_not_found} = ChannelAudienceLens.focus(%{"id" => "UC_missing"})
    end
  end

  describe "TrendingTopicsLens & YouTube Auth" do
    test "discovers trending videos and extracts top high-velocity keywords" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/search"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "pageInfo" => %{"totalResults" => 2},
            "items" => [
              %{
                "id" => %{"videoId" => "v1"},
                "snippet" => %{
                  "title" => "Autonomous Elixir Agents in Production",
                  "channelTitle" => "ElixirCast"
                }
              },
              %{
                "id" => %{"videoId" => "v2"},
                "snippet" => %{
                  "title" => "Building Autonomous Agents with Elixir",
                  "channelTitle" => "AgenticDev"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, result} = TrendingTopicsLens.focus(%{"q" => "Elixir Agents"})
      assert length(result.trending_videos) == 2
      assert "autonomous" in result.extracted_keywords
      assert "elixir" in result.extracted_keywords
      assert "agents" in result.extracted_keywords
    end

    test "validates schema requirements for VideoAnalyticsLens and TrendingTopicsLens" do
      assert VideoAnalyticsLens.view().schema.required == ["id"]
      assert TrendingTopicsLens.view().schema.required == ["q"]
    end

    test "attaches x-goog-api-key header on Plug.Conn via YouTube.add_auth/1" do
      conn = %Plug.Conn{} |> YouTube.add_auth()
      assert is_list(conn.req_headers)
    end
  end
end
