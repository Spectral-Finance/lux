defmodule Lux.Lenses.Youtube.Analytics.RevenueOptimization do
  @moduledoc """
  A lens for optimizing YouTube channel revenue.

  Features:
  - RPM (Revenue Per Mille) tracking and optimization
  - Monetization eligibility assessment
  - Revenue stream diversification recommendations
  - CPM benchmarking by content category

  ## Examples

      iex> RevenueOptimization.handler(%{
      ...>   channel_id: "UC123456"
      ...> }, %{name: "Agent"})
      {:ok, %{
        channel_id: "UC123456",
        monetization_eligible: true,
        estimated_rpm: 4.50,
        revenue_streams: ["ads", "memberships", "super_chat"]
      }}
  """

  use Lux.Lens,
    name: "YouTube Revenue Optimization",
    description: "Analyzes and optimizes revenue strategies for YouTube channels",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
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
        monetization_eligible: %{type: :boolean},
        estimated_rpm: %{type: :number},
        revenue_streams: %{type: :array},
        optimization_tips: %{type: :array}
      }
    }

  alias Lux.Integrations.Youtube.Client
  require Logger

  @cpm_benchmarks %{
    "finance" => 12.0,
    "tech" => 8.0,
    "education" => 6.0,
    "lifestyle" => 4.0,
    "entertainment" => 3.0,
    "gaming" => 2.5,
    "other" => 4.0
  }

  def handler(params, agent) do
    channel_id = params[:channel_id] || params["channel_id"]
    category = params[:category] || params["category"] || "other"
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} optimizing revenue for #{channel_id}")

    case Client.request(:get, "/channels", %{params: %{part: "statistics,status", id: channel_id}}) do
      {:ok, %{"items" => [channel | _]}} ->
        result = analyze_revenue(channel, category)
        {:ok, result}

      error ->
        Logger.error("Failed to optimize revenue: #{inspect(error)}")
        error
    end
  end

  defp analyze_revenue(channel, category) do
    stats = channel["statistics"] || %{}
    subs = String.to_integer(stats["subscriberCount"] || "0")
    views = String.to_integer(stats["viewCount"] || "0")

    eligible = subs >= 1000 && String.to_integer(stats["videoCount"] || "0") >= 4000

    rpm = Map.get(@cpm_benchmarks, category, 4.0) * (if subs > 100_000, do: 1.5, else: 1.0)

    %{
      channel_id: channel["id"],
      monetization_eligible: eligible,
      estimated_rpm: Float.round(rpm, 2),
      estimated_monthly_revenue: Float.round(views * rpm / 1000 / 12, 2),
      revenue_streams: identify_revenue_streams(subs, eligible),
      optimization_tips: generate_tips(category, subs, views)
    }
  end

  defp identify_revenue_streams(subs, true) when subs >= 30_000 do
    ["ads", "memberships", "super_chat", "super_thanks", "merchandise", "sponsorships"]
  end
  defp identify_revenue_streams(subs, true) when subs >= 1000 do
    ["ads", "memberships", "super_chat", "super_thanks"]
  end
  defp identify_revenue_streams(_, false), do: ["not_yet_monetized"]

  defp generate_tips(category, subs, views) do
    tips = [
      "Optimize video length to 8-15 minutes for mid-roll ad placement"
    ]
    tips = if category in ["finance", "tech"], do: ["Create advertiser-friendly content - #{category} has #{Map.get(@cpm_benchmarks, category)}x higher CPM" | tips], else: tips
    tips = if subs < 1000, do: ["Focus on watch time - need 4000 hours for monetization" | tips], else: tips
    tips = if subs >= 1000 and subs < 10_000, do: ["Enable memberships at $0.99 tier for low-barrier entry" | tips], else: tips
    tips
  end
end
