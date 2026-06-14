defmodule Lux.Prisms.YouTube.YouTubeGrowthPrism do
  @moduledoc """
  A prism for YouTube channel growth analysis and prediction.

  ## Example

      iex> Lux.Prisms.YouTube.YouTubeGrowthPrism.handler(%{
      ...>   action: "growth_report"
      ...> }, %{})
  """

  use Lux.Prism,
    name: "YouTube Growth Engine",
    description: "Analyzes YouTube channel growth trends and predicts future performance",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["growth_report", "predict_growth", "competitor_analysis", "revenue_estimate", "channel_audit"],
          description: "Action to perform"
        },
        channel_id: %{type: :string, description: "YouTube channel ID to analyze"},
        days: %{type: :integer, description: "Days to analyze", default: 30}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        report: %{type: :object},
        prediction: %{type: :object},
        audit: %{type: :object}
      },
      required: ["status"]
    }

  require Logger

  @api "https://www.googleapis.com/youtube/v3"

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key() do
      case input.action do
        "growth_report"       -> growth_report(api_key, input)
        "predict_growth"      -> predict_growth(api_key, input)
        "competitor_analysis" -> competitor_analysis(api_key, input)
        "revenue_estimate"    -> revenue_estimate(api_key, input)
        "channel_audit"       -> channel_audit(api_key, input)
        _                     -> {:error, "Unknown action: #{input.action}"}
      end
    end
  end

  defp get_api_key do
    key = Lux.Config.get(:youtube_api_key) || System.get_env("YOUTUBE_API_KEY")
    if key, do: {:ok, key}, else: {:error, "YouTube API key not configured"}
  rescue
    _ -> {:error, "YouTube API key not configured"}
  end

  defp growth_report(api_key, input) do
    channel_id = Map.get(input, :channel_id, "mine")
    params = if channel_id == "mine",
      do: %{part: "snippet,statistics", mine: true, key: api_key},
      else: %{part: "snippet,statistics", id: channel_id, key: api_key}

    case Req.get("#{@api}/channels", params: params) do
      {:ok, %{status: 200, body: %{"items" => [channel | _]}}} ->
        stats = channel["statistics"] || %{}
        subs = String.to_integer(stats["subscriberCount"] || "0")
        views = String.to_integer(stats["viewCount"] || "0")
        videos = String.to_integer(stats["videoCount"] || "1")

        {:ok, %{
          status: "success",
          report: %{
            channel_id: channel["id"],
            title: get_in(channel, ["snippet", "title"]),
            subscribers: subs,
            total_views: views,
            video_count: videos,
            avg_views_per_video: div(views, max(videos, 1)),
            engagement_rate: Float.round(views / max(subs, 1) * 100, 2),
            growth_score: calculate_growth_score(subs, views, videos)
          }
        }}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp predict_growth(api_key, input) do
    with {:ok, report} <- growth_report(api_key, input) do
      subs = report.report.subscribers
      days = Map.get(input, :days, 30)
      daily_growth_rate = 0.02
      predicted_subs = round(subs * :math.pow(1 + daily_growth_rate, days))

      {:ok, %{
        status: "success",
        prediction: %{
          current_subscribers: subs,
          predicted_subscribers_30d: predicted_subs,
          predicted_subscribers_90d: round(subs * :math.pow(1 + daily_growth_rate, 90)),
          predicted_subscribers_1y: round(subs * :math.pow(1 + daily_growth_rate, 365)),
          growth_rate_daily: "#{daily_growth_rate * 100}%",
          days_analyzed: days
        }
      }}
    end
  end

  defp competitor_analysis(api_key, input) do
    channel_id = Map.get(input, :channel_id)
    if is_nil(channel_id) do
      {:error, "channel_id required for competitor analysis"}
    else
      case Req.get("#{@api}/channels", params: %{part: "snippet,statistics", id: channel_id, key: api_key}) do
        {:ok, %{status: 200, body: %{"items" => [channel | _]}}} ->
          stats = channel["statistics"] || %{}
          subs = String.to_integer(stats["subscriberCount"] || "0")
          {:ok, %{
            status: "success",
            report: %{
              channel_id: channel["id"],
              title: get_in(channel, ["snippet", "title"]),
              subscribers: subs,
              total_views: String.to_integer(stats["viewCount"] || "0"),
              video_count: String.to_integer(stats["videoCount"] || "0"),
              competitive_score: calculate_growth_score(
                subs,
                String.to_integer(stats["viewCount"] || "0"),
                String.to_integer(stats["videoCount"] || "1")
              )
            }
          }}
        {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
        {:error, r} -> {:error, inspect(r)}
      end
    end
  end

  defp revenue_estimate(api_key, input) do
    with {:ok, report} <- growth_report(api_key, input) do
      views = report.report.total_views
      rpm_low = 1.0
      rpm_high = 5.0
      {:ok, %{
        status: "success",
        report: %{
          total_views: views,
          estimated_revenue_low_usd: Float.round(views / 1000 * rpm_low, 2),
          estimated_revenue_high_usd: Float.round(views / 1000 * rpm_high, 2),
          rpm_range: "$#{rpm_low} - $#{rpm_high} per 1000 views",
          note: "Estimates based on average YouTube RPM rates"
        }
      }}
    end
  end

  defp channel_audit(api_key, input) do
    with {:ok, report} <- growth_report(api_key, input) do
      score = report.report.growth_score
      recommendations = build_recommendations(report.report)
      {:ok, %{
        status: "success",
        audit: %{
          channel_title: report.report.title,
          overall_score: score,
          grade: grade_score(score),
          subscribers: report.report.subscribers,
          total_views: report.report.total_views,
          avg_views_per_video: report.report.avg_views_per_video,
          engagement_rate: report.report.engagement_rate,
          recommendations: recommendations
        }
      }}
    end
  end

  defp calculate_growth_score(subs, views, videos) do
    sub_score = min(subs / 1000, 40)
    view_score = min(views / 10_000, 40)
    consistency_score = min(videos / 10, 20)
    Float.round(sub_score + view_score + consistency_score, 1)
  end

  defp grade_score(score) when score >= 80, do: "A"
  defp grade_score(score) when score >= 60, do: "B"
  defp grade_score(score) when score >= 40, do: "C"
  defp grade_score(score) when score >= 20, do: "D"
  defp grade_score(_), do: "F"

  defp build_recommendations(report) do
    []
    |> maybe_add(report.subscribers < 1000, "Focus on growing subscribers to 1000 for monetization")
    |> maybe_add(report.avg_views_per_video < 500, "Improve thumbnails and titles to increase click-through rate")
    |> maybe_add(report.engagement_rate < 10, "Create more engaging content to improve viewer retention")
    |> maybe_add(report.video_count < 10, "Post more consistently to build channel authority")
  end

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _), do: list
end
