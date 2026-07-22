defmodule Lux.Integration.Agents.YouTubeContentIntelligenceTest do
  use ExUnit.Case, async: true

  alias Lux.Agents.YouTubeContentIntelligence

  @moduletag :integration

  setup do
    Application.put_env(:lux, Lux.LLM.OpenAI, plug: {Req.Test, Lux.LLM.OpenAI})

    Req.Test.stub(Lux.LLM.OpenAI, fn conn ->
      Req.Test.json(conn, %{
        "model" => "gpt-4o-mini",
        "choices" => [
          %{
            "message" => %{
              "content" => Jason.encode!(%{
                "title" => "Optimized Video Title: 10 Growth Hacks",
                "description" => "Comprehensive SEO-optimized video description...",
                "tags" => ["youtube", "content strategy", "analytics"],
                "thumbnails_ideas" => ["High contrast bold text", "Creator reaction thumbnail"],
                "engagement_analysis" => "Strong early retention in first 60 seconds",
                "trending_topics" => ["AI content creation", "YouTube Shorts"],
                "content_recommendations" => ["Follow-up tutorial on analytics", "Q&A session"]
              })
            },
            "finish_reason" => "stop"
          }
        ]
      })
    end)

    {:ok, agent} = YouTubeContentIntelligence.start_link([])
    Req.Test.allow(Lux.LLM.OpenAI, self(), agent)
    %{agent: agent}
  end

  describe "optimize_content/2" do
    test "returns optimized metadata by mocking LLM response credential-free", %{agent: agent} do
      video_context = %{
        "title" => "Raw Video Title",
        "metrics" => %{"views" => 1200, "likes" => 150}
      }

      assert {:ok, result} = YouTubeContentIntelligence.optimize_content(agent, video_context)
      assert result.title == "Optimized Video Title: 10 Growth Hacks"
      assert result.description =~ "SEO-optimized"
      assert "youtube" in result.tags
      assert length(result.thumbnails_ideas) == 2
      assert result.engagement_analysis =~ "retention"
      assert length(result.trending_topics) == 2
      assert length(result.content_recommendations) == 2
    end
  end

  describe "predict_performance/1" do
    test "predict_performance returns optimal posting hour and predicted views based on mock metrics" do
      historical_metrics = [
        %{"hour" => 10, "views" => 1000},
        %{"hour" => 10, "views" => 1500},
        %{"hour" => 18, "views" => 5000},
        %{"hour" => 18, "views" => 6000},
        %{"hour" => 20, "views" => 3000}
      ]

      result = YouTubeContentIntelligence.predict_performance(historical_metrics)

      assert result["optimal_posting_hour"] == 18
      assert result["predicted_views"] == trunc(5500 * 1.15)
      assert result["confidence_score"] == 0.5
      assert result["estimated_retention"] == 50.0
    end

    test "predict_performance handles empty metrics gracefully" do
      result = YouTubeContentIntelligence.predict_performance([])
      assert result["optimal_posting_hour"] == 17
      assert result["predicted_views"] == 5000
      assert result["confidence_score"] == 0.5
      assert result["estimated_retention"] == 50.0
    end

    test "predict_performance clamps estimated_retention to percentage [0..100] and prevents negative/out-of-bounds metrics" do
      out_of_bounds_metrics = [
        %{"hour" => -5, "views" => -500, "estimated_retention" => -25.0},
        %{"hour" => 30, "views" => 1000, "estimated_retention" => 150.0}
      ]

      result = YouTubeContentIntelligence.predict_performance(out_of_bounds_metrics)

      assert result["optimal_posting_hour"] in 0..23
      assert result["predicted_views"] >= 0
      assert result["estimated_retention"] >= 0.0 and result["estimated_retention"] <= 100.0
      assert result["confidence_score"] >= 0.0 and result["confidence_score"] <= 1.0
      assert result["estimated_retention"] == 50.0
    end
  end

  describe "calculate_metrics/1 and clamp_retention/1" do
    test "clamp_retention/1 strictly clamps retention values to [0.0..100.0]" do
      assert YouTubeContentIntelligence.clamp_retention(-10.0) == 0.0
      assert YouTubeContentIntelligence.clamp_retention(120.0) == 100.0
      assert YouTubeContentIntelligence.clamp_retention(75.5) == 75.5
      assert YouTubeContentIntelligence.clamp_retention(0) == 0.0
      assert YouTubeContentIntelligence.clamp_retention(100) == 100.0
      assert YouTubeContentIntelligence.clamp_retention(nil) == 0.0
    end

    test "calculate_metrics/1 handles negative or out-of-bounds metrics" do
      metrics = [
        %{"hour" => -1, "views" => -100, "estimated_retention" => -50.0},
        %{"hour" => 25, "views" => 200, "estimated_retention" => 200.0}
      ]

      summary = YouTubeContentIntelligence.calculate_metrics(metrics)
      assert summary.estimated_retention >= 0.0 and summary.estimated_retention <= 100.0
      assert summary.estimated_retention == 50.0

      [item1, item2] = summary.metrics
      assert item1.hour == 0
      assert item1.views == 0
      assert item1.estimated_retention == 0.0
      assert item2.hour == 23
      assert item2.views == 200
      assert item2.estimated_retention == 100.0
    end
  end
end
