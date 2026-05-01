defmodule Lux.Prisms.Youtube.Analytics.GrowthReport do
  @moduledoc """
  A prism for generating comprehensive YouTube growth analytics reports.

  Aggregates data from multiple YouTube analytics lenses to provide
  a holistic view of channel performance, growth trends, and optimization
  opportunities.

  ## Examples

      iex> GrowthReport.handler(%{
      ...>   channel_id: "UC123456",
      ...>   competitor_ids: ["UC789012"],
      ...>   category: "tech"
      ...> }, %{name: "Agent"})
      {:ok, %{
        channel_id: "UC123456",
        report_type: "growth_analytics",
        metrics: %{...},
        competitors: [%{...}],
        growth: %{...},
        revenue: %{...},
        retention: %{...}
      }}
  """

  use Lux.Prism,
    name: "YouTube Growth Analytics Report",
    description: "Generates comprehensive growth analytics report for a YouTube channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
        },
        competitor_ids: %{
          type: :array,
          description: "Optional list of competitor channel IDs",
          items: %{type: :string}
        },
        period: %{
          type: :string,
          description: "Analysis period: 7d, 30d, 90d",
          enum: ["7d", "30d", "90d"],
          default: "30d"
        },
        category: %{
          type: :string,
          description: "Content category for CPM benchmarking",
          enum: ["tech", "finance", "gaming", "education", "entertainment", "lifestyle", "other"],
          default: "other"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        report_type: %{type: :string},
        generated_at: %{type: :string},
        metrics: %{type: :object},
        growth: %{type: :object},
        revenue: %{type: :object},
        retention: %{type: :object},
        competitors: %{type: :array},
        recommendations: %{type: :array}
      },
      required: ["channel_id", "report_type"]
    }

  alias Lux.Lenses.Youtube.Analytics.{ChannelMetrics, GrowthTrends, RevenueOptimization, AudienceRetention, CompetitorAnalysis}
  require Logger

  def handler(params, agent) do
    channel_id = params[:channel_id] || params["channel_id"]
    competitor_ids = params[:competitor_ids] || params["competitor_ids"] || []
    period = params[:period] || params["period"] || "30d"
    category = params[:category] || params["category"] || "other"
    agent_name = agent[:name] || "Unknown Agent"

    Logger.info("Agent #{agent_name} generating growth report for #{channel_id}")

    with {:ok, metrics} <- ChannelMetrics.handler(%{channel_id: channel_id}, agent),
         {:ok, growth} <- GrowthTrends.handler(%{channel_id: channel_id, period: period}, agent),
         {:ok, revenue} <- RevenueOptimization.handler(%{channel_id: channel_id, category: category}, agent),
         {:ok, retention} <- AudienceRetention.handler(%{channel_id: channel_id}, agent),
         {:ok, competitors} <- maybe_fetch_competitors(channel_id, competitor_ids, agent) do

      {:ok, %{
        channel_id: channel_id,
        report_type: "growth_analytics",
        generated_at: DateTime.utc_now() |> DateTime.to_string(),
        metrics: metrics,
        growth: growth,
        revenue: revenue,
        retention: retention,
        competitors: competitors,
        recommendations: compile_recommendations(metrics, growth, revenue, retention)
      }}
    else
      error ->
        Logger.error("Failed to generate growth report: #{inspect(error)}")
        error
    end
  end

  defp maybe_fetch_competitors(_channel_id, [], _agent), do: {:ok, []}
  defp maybe_fetch_competitors(channel_id, competitor_ids, agent) do
    case CompetitorAnalysis.handler(%{channel_id: channel_id, competitor_ids: competitor_ids}, agent) do
      {:ok, result} -> {:ok, result[:competitors] || result["competitors"] || []}
      {:error, _} -> {:ok, []}
    end
  end

  defp compile_recommendations(metrics, growth, revenue, retention) do
    recs = []

    recs = case growth[:trend] || growth["trend"] do
      "accelerating" -> ["Current momentum is strong - maintain upload consistency" | recs]
      "declining" -> ["Urgent: Review recent content strategy for drop-off causes" | recs]
      _ -> recs
    end

    recs = if revenue[:monetization_eligible] || revenue["monetization_eligible"] do
      ["Explore additional revenue streams: memberships, super chat, merchandise" | recs]
    else
      ["Focus on reaching monetization thresholds (1000 subs, 4000 watch hours)" | recs]
    end

    recs = if (retention[:avg_retention_rate] || retention["avg_retention_rate"] || 0) < 40 do
      "Improve audience retention - current rate is below 40% benchmark" | recs
    else
      recs
    end

    if recs == [], do: ["Continue current growth strategy"], else: recs
  end
end
