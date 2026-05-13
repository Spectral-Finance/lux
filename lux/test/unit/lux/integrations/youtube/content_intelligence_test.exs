defmodule Lux.Integrations.YouTube.ContentIntelligenceTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.ContentIntelligence

  @video %{
    id: "video-1",
    title: "Elixir agents for YouTube growth",
    summary: "A practical walkthrough.",
    views: 1_000,
    likes: 40,
    comments: 10,
    shares: 5,
    impressions: 5_000,
    clicks: 250,
    duration_seconds: 300,
    average_view_duration_seconds: 120,
    tags: ["elixir", "agents"]
  }

  describe "performance_score/1" do
    test "scores engagement, click-through, and retention" do
      score = ContentIntelligence.performance_score(@video)

      assert score.video_id == "video-1"
      assert score.engagement_rate == 0.055
      assert score.click_through_rate == 0.05
      assert score.retention_rate == 0.4
      assert score.score == 17.43
    end
  end

  describe "recommendations/1" do
    test "prioritizes low CTR, low retention, low engagement, and sparse tags" do
      recommendations =
        ContentIntelligence.recommendations(
          Map.merge(@video, %{
            clicks: 10,
            average_view_duration_seconds: 60,
            likes: 5,
            comments: 1,
            shares: 0,
            tags: ["elixir"]
          })
        )

      assert Enum.any?(recommendations, &(&1.area == :thumbnail and &1.priority == :high))
      assert Enum.any?(recommendations, &(&1.area == :script and &1.priority == :high))
      assert Enum.any?(recommendations, &(&1.area == :engagement and &1.priority == :medium))
      assert Enum.any?(recommendations, &(&1.area == :tags and &1.priority == :low))
    end
  end

  describe "posting_windows/1" do
    test "ranks posting windows by average engagement" do
      [top | rest] =
        ContentIntelligence.posting_windows([
          %{weekday: "Tuesday", hour: 9, engagements: 100},
          %{weekday: "Tuesday", hour: 9, engagements: 200},
          %{weekday: "Friday", hour: 18, engagements: 120}
        ])

      assert top.weekday == "Tuesday"
      assert top.hour == 9
      assert top.sample_count == 2
      assert top.average_engagements == 150.0
      assert [%{weekday: "Friday"}] = rest
    end
  end

  describe "optimize_metadata/2" do
    test "generates title, description, tags, and trend matches" do
      metadata =
        ContentIntelligence.optimize_metadata(
          %{
            topic: "Elixir agents for YouTube growth",
            summary: "Build channel analytics with agents.",
            tags: ["Elixir", "YouTube"]
          },
          %{
            trends: [
              %{term: "AI agents", score: 20},
              %{term: "gardening", score: 50}
            ]
          }
        )

      assert metadata.title =~ "Elixir agents"
      assert metadata.title =~ "AI agents"
      assert "ai agents" in metadata.tags
      assert "elixir" in metadata.tags
      assert [%{term: "AI agents"} | _] = metadata.matched_trends
      assert metadata.description =~ "#elixir"
    end
  end

  describe "match_trends/2" do
    test "ranks trends by base score plus topic overlap" do
      [first | _] =
        ContentIntelligence.match_trends("YouTube AI agents", [
          %{term: "AI agents", score: 10},
          %{term: "YouTube thumbnail", score: 5}
        ])

      assert first.term == "AI agents"
      assert first.overlap == 2
    end
  end

  describe "content_report/2" do
    test "builds an end-to-end optimization report" do
      report =
        ContentIntelligence.content_report(@video, %{
          trends: [%{term: "AI agents", score: 20}],
          posting_samples: [%{weekday: "Tuesday", hour: 9, engagements: 100}]
        })

      assert report.video_id == "video-1"
      assert report.performance.score == 17.43
      assert [%{weekday: "Tuesday", hour: 9}] = report.posting_windows
      assert report.metadata.title =~ "AI agents"
    end
  end
end
