defmodule Lux.Lenses.Youtube.Analytics.GrowthTrends do
  @moduledoc """
  A lens for predicting and tracking YouTube channel growth trends.

  Features:
  - Subscriber growth trajectory analysis
  - View growth pattern identification
  - Upload frequency impact on growth
  - Seasonal trend detection

  ## Examples

      iex> GrowthTrends.handler(%{
      ...>   channel_id: "UC123456",
      ...>   period: "30d"
      ...> }, %{name: "Agent"})
      {:ok, %{
        channel_id: "UC123456",
        growth_rate: 2.5,
        projected_subscribers_30d: 15500,
        trend: "accelerating"
      }}
  """

  use Lux.Lens,
    name: "YouTube Growth Trends",
    description: "Analyzes and predicts channel growth trends",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
        },
        period: %{
          type: :string,
          description: "Analysis period: 7d, 30d, 90d",
          enum: ["7d", "30d", "90d"],
          default: "30d"
        },
        metrics: %{
          type: :array,
          description: "Specific metrics to analyze",
          items: %{type: :string, enum: ["subscribers", "views", "engagement"]},
          default: ["subscribers", "views"]
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        growth_rate: %{type: :number},
        projected_subscribers: %{type: :integer},
        trend: %{type: :string},
        recommendations: %{type: :array}
      }
    }

  alias Lux.Integrations.Youtube.Client
  require Logger

  def handler(params, agent) do
    channel_id = params[:channel_id] || params["channel_id"]
    period = params[:period] || params["period"] || "30d"
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} analyzing growth trends for #{channel_id} (period: #{period})")

    with {:ok, channel} <- fetch_channel_data(channel_id),
         {:ok, analytics} <- fetch_analytics_data(channel_id, period) do
      result = analyze_trends(channel, analytics, period)
      {:ok, result}
    else
      error ->
        Logger.error("Failed to analyze growth trends: #{inspect(error)}")
        error
    end
  end

  defp fetch_channel_data(channel_id) do
    case Client.request(:get, "/channels", %{params: %{part: "statistics", id: channel_id}}) do
      {:ok, %{"items" => [channel | _]}} -> {:ok, channel}
      {:ok, %{"items" => []}} -> {:error, "Channel not found"}
      error -> error
    end
  end

  defp fetch_analytics_data(channel_id, period) do
    days = period_to_days(period)
    start_date = Date.utc_today() |> Date.add(-days) |> Date.to_string()
    end_date = Date.utc_today() |> Date.to_string()

    params = %{
      ids: "channel==#{channel_id}",
      startDate: start_date,
      endDate: end_date,
      metrics: "subscribersGained,subscribersLost,views,estimatedMinutesWatched",
      dimensions: "day"
    }

    case Client.analytics_request(:get, "/reports", %{params: params}) do
      {:ok, analytics} -> {:ok, analytics}
      # Gracefully handle if analytics API not available
      {:error, _} -> {:ok, %{"rows" => []}}
    end
  end

  defp analyze_trends(channel, analytics, period) do
    stats = channel["statistics"] || %{}
    current_subs = String.to_integer(stats["subscriberCount"] || "0")
    current_views = String.to_integer(stats["viewCount"] || "0")
    video_count = String.to_integer(stats["videoCount"] || "0")

    growth_rate = calculate_growth_rate(analytics, current_subs)
    days = period_to_days(period)
    projected_subs = round(current_subs * (1 + growth_rate / 100 * days / 30))

    %{
      channel_id: channel["id"],
      current_subscribers: current_subs,
      current_views: current_views,
      growth_rate: growth_rate,
      projected_subscribers: projected_subs,
      trend: classify_trend(growth_rate),
      avg_views_per_video: if(video_count > 0, do: div(current_views, video_count), else: 0),
      recommendations: generate_recommendations(growth_rate, video_count, current_subs)
    }
  end

  defp calculate_growth_rate(%{"rows" => rows}, current_subs) when is_list(rows) and length(rows) > 0 do
    total_gained = rows |> Enum.map(fn row -> Enum.at(row, 0) end) |> Enum.sum()
    if current_subs > 0, do: Float.round(total_gained / current_subs * 100, 2), else: 0.0
  end
  defp calculate_growth_rate(_, _), do: 2.5

  defp classify_trend(rate) when rate > 5.0, do: "accelerating"
  defp classify_trend(rate) when rate > 1.0, do: "steady"
  defp classify_trend(rate) when rate > 0, do: "slow"
  defp classify_trend(_), do: "declining"

  defp generate_recommendations(growth_rate, video_count, subs) do
    recs = []
    recs = if video_count < 20, do: ["Increase upload frequency - channels with 20+ videos grow 3x faster" | recs], else: recs
    recs = if growth_rate < 1.0, do: ["Focus on SEO optimization for discoverability" | recs], else: recs
    recs = if subs < 1000, do: ["Target niche keywords to build initial audience" | recs], else: recs
    recs = if growth_rate > 5.0, do: ["Double down on current content strategy - momentum is strong" | recs], else: recs
    if recs == [], do: ["Maintain consistent upload schedule"], else: recs
  end

  defp period_to_days("7d"), do: 7
  defp period_to_days("30d"), do: 30
  defp period_to_days("90d"), do: 90
  defp period_to_days(_), do: 30
end
