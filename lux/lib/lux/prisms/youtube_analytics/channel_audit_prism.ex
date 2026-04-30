defmodule Lux.Prisms.YoutubeAnalytics.ChannelAuditPrism do
  @moduledoc """
  Prism for automated YouTube channel health audit with actionable recommendations.

  Performs comprehensive channel analysis including SEO, content strategy,
  engagement metrics, and growth potential assessment.
  """

  use Lux.Prism,
    name: "YouTube Channel Audit",
    description: "Automated channel health audit with SEO, content, and engagement analysis",
    input_schema: %{
      type: :object,
      properties: %{
        channel_metrics: %{
          type: :object,
          properties: %{
            subscriber_count: %{type: :integer},
            view_count: %{type: :integer},
            video_count: %{type: :integer},
            country: %{type: :string},
            default_language: %{type: :string}
          },
          description: "Channel-level metrics"
        },
        recent_videos: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              video_id: %{type: :string},
              title: %{type: :string},
              description: %{type: :string},
              tags: %{type: :array},
              view_count: %{type: :integer},
              like_count: %{type: :integer},
              comment_count: %{type: :integer},
              published_at: %{type: :string},
              duration: %{type: :string}
            }
          },
          description: "Recent video data for analysis"
        },
        audit_depth: %{
          type: :string,
          description: "Audit depth level",
          enum: ["quick", "standard", "comprehensive"],
          default: "standard"
        }
      },
      required: ["channel_metrics", "recent_videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        audit_score: %{type: :integer},
        grade: %{type: :string},
        categories: %{
          type: :object,
          properties: %{
            seo: %{type: :integer},
            engagement: %{type: :integer},
            content_quality: %{type: :integer},
            consistency: %{type: :integer},
            growth_potential: %{type: :integer}
          }
        },
        issues: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              category: %{type: :string},
              severity: %{type: :string},
              description: %{type: :string},
              recommendation: %{type: :string}
            }
          }
        },
        recommendations: %{type: :array, items: %{type: :string}}
      }
    }

  @doc """
  Perform channel audit.
  """
  def transform(params) when is_map(params) do
    channel_metrics = Map.get(params, :channel_metrics, %{})
    recent_videos = Map.get(params, :recent_videos, [])

    seo_score = audit_seo(recent_videos)
    engagement_score = audit_engagement(recent_videos)
    content_score = audit_content_quality(recent_videos)
    consistency_score = audit_consistency(recent_videos)
    growth_score = audit_growth_potential(channel_metrics)

    categories = %{seo: seo_score, engagement: engagement_score, content_quality: content_score, consistency: consistency_score, growth_potential: growth_score}
    overall_score = round((seo_score + engagement_score + content_score + consistency_score + growth_score) / 5)
    grade = score_to_grade(overall_score)
    issues = collect_issues(categories, recent_videos)
    recommendations = generate_recommendations(categories)

    {:ok, %{audit_score: overall_score, grade: grade, categories: categories, issues: issues, recommendations: recommendations}}
  end

  defp audit_seo(videos) when length(videos) == 0, do: 0
  defp audit_seo(videos) do
    with_tags = Enum.count(videos, &(Map.get(&1, :tags, []) |> length() > 3))
    with_desc = Enum.count(videos, &(&1.description && String.length(&1.description) > 100))
    tag_score = round(with_tags / length(videos) * 40)
    desc_score = round(with_desc / length(videos) * 30)
    title_score = 20
    min(100, tag_score + desc_score + title_score)
  end

  defp audit_engagement(videos) when length(videos) == 0, do: 0
  defp audit_engagement(videos) do
    avg_eng = Enum.map(videos, fn v ->
      views = v.view_count || 0
      if views > 0, do: ((v.like_count || 0) + (v.comment_count || 0)) / views * 100, else: 0
    end) |> then(&Enum.sum(&1) / length(&1))

    cond do
      avg_eng >= 5.0 -> 100
      avg_eng >= 3.0 -> 80
      avg_eng >= 1.5 -> 60
      avg_eng >= 0.5 -> 40
      true -> 20
    end
  end

  defp audit_content_quality(videos) when length(videos) == 0, do: 0
  defp audit_content_quality(videos) do
    has_variety = length(Enum.uniq_by(videos, &(&1.duration || ""))) > 1
    50 + if(has_variety, do: 20, else: 0) + 30 |> min(100)
  end

  defp audit_consistency(videos) when length(videos) < 2, do: 30
  defp audit_consistency(videos) do
    sorted = Enum.sort_by(videos, &(&1.published_at || ""))
    dates = Enum.map(sorted, &(&1.published_at || "")) |> Enum.filter(&(&1 != ""))
    if length(dates) < 2, do: 30,
    else
      intervals = Enum.zip(dates, Enum.drop(dates, 1)) |> Enum.map(fn {d1, d2} ->
        try do: Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1)), catch: _, _ -> 7
      end)
      avg_interval = Enum.sum(intervals) / length(intervals)
      cond do
        avg_interval <= 3 -> 100
        avg_interval <= 7 -> 80
        avg_interval <= 14 -> 60
        avg_interval <= 30 -> 40
        true -> 20
      end
    end
  end

  defp audit_growth_potential(cm) do
    subs = cm.subscriber_count || 0
    cond do
      subs < 1000 -> 90
      subs < 10000 -> 70
      subs < 100000 -> 50
      subs < 1000000 -> 30
      true -> 20
    end
  end

  defp score_to_grade(s) when s >= 90, do: "A"
  defp score_to_grade(s) when s >= 80, do: "B"
  defp score_to_grade(s) when s >= 70, do: "C"
  defp score_to_grade(s) when s >= 60, do: "D"
  defp score_to_grade(_), do: "F"

  defp collect_issues(cat, videos, _cm \\ %{})
  defp collect_issues(cat, _videos) do
    issues = []
    issues = if cat.seo < 60, do: [%{category: "SEO", severity: "high", description: "Low SEO score", recommendation: "Add tags and descriptions"} | issues], else: issues
    issues = if cat.engagement < 60, do: [%{category: "Engagement", severity: "medium", description: "Low engagement", recommendation: "Add CTAs and respond to comments"} | issues], else: issues
    issues = if cat.consistency < 60, do: [%{category: "Consistency", severity: "high", description: "Irregular uploads", recommendation: "Establish consistent schedule"} | issues], else: issues
    Enum.reverse(issues)
  end

  defp generate_recommendations(cat) do
    recs = []
    recs = if cat.seo < 70, do: ["Optimize video titles with target keywords (40-60 chars)"] ++ recs, else: recs
    recs = if cat.engagement < 70, do: ["Add end screens and cards to increase watch time"] ++ recs, else: recs
    recs = if cat.consistency < 70, do: ["Create content calendar and batch-produce videos"] ++ recs, else: recs
    ["Analyze top-performing videos and replicate patterns", "Use YouTube Analytics for best posting times"] ++ recs
  end
end
