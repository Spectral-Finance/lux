defmodule Lux.Integration.YouTubeContentIntelligenceWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.YouTube.ContentIntelligence

  @tag :integration
  test "showcases content optimization workflow from collected data to report" do
    raw = %{
      "items" => [
        %{
          "id" => "video-1",
          "snippet" => %{
            "title" => "Elixir AI agents for YouTube growth",
            "description" => "Build analytics agents.",
            "tags" => ["elixir", "agents"]
          },
          "statistics" => %{"viewCount" => "10000", "likeCount" => "300", "commentCount" => "80"},
          "contentDetails" => %{"duration" => "PT10M"}
        }
      ]
    }

    [video] = ContentIntelligence.process_video_records(raw)

    report =
      video
      |> Map.merge(%{
        impressions: 50_000,
        clicks: 3_000,
        average_view_duration_seconds: 270,
        shares: 40
      })
      |> ContentIntelligence.content_report(%{
        trends: [%{term: "AI agents", score: 40}],
        historical_samples: [%{views: 4_000}, %{views: 7_000}],
        posting_samples: [%{weekday: "Tuesday", hour: 9, engagements: 100}]
      })

    assert report.analytics.engagement_rate > 0
    assert report.prediction.predicted_views.mid > 0
    assert report.metadata.title =~ "AI agents"
    assert [%{weekday: "Tuesday"}] = report.posting_windows
  end
end
