defmodule Lux.Integrations.YouTube.ContentIntelligenceTest do
  use UnitCase, async: true

  alias Lux.Integrations.YouTube.ContentIntelligence

  @video %{
    id: "video-1",
    title: "Elixir AI agents for YouTube growth",
    summary: "Build analytics agents for a YouTube channel.",
    views: 10_000,
    likes: 300,
    comments: 80,
    shares: 40,
    impressions: 50_000,
    clicks: 3_000,
    duration_seconds: 600,
    average_view_duration_seconds: 270,
    tags: ["Elixir", "AI agents"]
  }

  test "processes YouTube video records" do
    records =
      ContentIntelligence.process_video_records(%{
        "items" => [
          %{
            "id" => "abc",
            "snippet" => %{"title" => "Demo", "tags" => ["elixir"]},
            "statistics" => %{"viewCount" => "100", "likeCount" => "5", "commentCount" => "2"},
            "contentDetails" => %{"duration" => "PT1H2M3S"}
          }
        ]
      })

    assert [%{id: "abc", views: 100, likes: 5, comments: 2, duration_seconds: 3723}] = records
  end

  test "processes YouTube analytics report rows" do
    rows =
      ContentIntelligence.process_analytics_report(%{
        "columnHeaders" => [%{"name" => "day"}, %{"name" => "views"}, %{"name" => "likes"}],
        "rows" => [["2026-01-01", 100, 7]]
      })

    assert [%{"day" => "2026-01-01", "views" => 100, "likes" => 7}] = rows
  end

  test "analyzes engagement and recommends improvements" do
    metrics = ContentIntelligence.engagement_analysis(@video)

    assert metrics.engagement_rate > 0.04
    assert metrics.click_through_rate == 0.06
    assert metrics.retention_rate == 0.45

    assert ContentIntelligence.recommendations(%{
             @video
             | clicks: 100,
               average_view_duration_seconds: 60
           })
           |> Enum.any?(&(&1.area == :thumbnail))
  end

  test "trains model and predicts performance" do
    model = ContentIntelligence.train_performance_model([%{views: 1_000}, %{views: 3_000}])
    prediction = ContentIntelligence.predict_performance(@video, model)

    assert model.base_views == 2_000
    assert prediction.predicted_views.mid > 0
    assert prediction.confidence > 0.5
  end

  test "generates metadata from topic and trends" do
    metadata =
      ContentIntelligence.generate_metadata(@video, %{
        trends: [%{term: "AI agents", score: 40}, %{term: "cooking", score: 100}]
      })

    assert metadata.title =~ "AI agents"
    assert metadata.thumbnail.primary_text == "AI agents"
    assert "ai agents" in metadata.tags
    assert metadata.description =~ "#"
    assert [%{term: "AI agents"}] = metadata.matched_trends
  end

  test "ranks posting windows" do
    [best | _] =
      ContentIntelligence.posting_time_prediction([
        %{weekday: "Tuesday", hour: 9, engagements: 100},
        %{weekday: "Tuesday", hour: 9, engagements: 300},
        %{weekday: "Friday", hour: 18, engagements: 50}
      ])

    assert best.weekday == "Tuesday"
    assert best.hour == 9
    assert best.expected_engagements == 200
  end

  test "builds complete content report" do
    report =
      ContentIntelligence.content_report(@video, %{
        trends: [%{term: "AI agents", score: 40}],
        historical_samples: [%{views: 1_000}, %{views: 2_000}],
        posting_samples: [%{weekday: "Monday", hour: 10, engagements: 42}]
      })

    assert report.video_id == "video-1"
    assert report.prediction.predicted_views.mid > 0
    assert report.metadata.title
    assert [%{weekday: "Monday"}] = report.posting_windows
  end
end
