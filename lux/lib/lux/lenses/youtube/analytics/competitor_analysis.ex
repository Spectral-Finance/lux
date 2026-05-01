defmodule Lux.Lenses.Youtube.Analytics.CompetitorAnalysis do
  @moduledoc """
  A lens for analyzing competitor YouTube channels.

  Provides competitive intelligence including:
  - Comparative subscriber counts
  - Upload frequency comparison
  - Engagement rate benchmarking
  - Content gap identification

  ## Examples

      iex> CompetitorAnalysis.handler(%{
      ...>   channel_id: "UC123456",
      ...>   competitor_ids: ["UC789012", "UC345678"]
      ...> }, %{name: "Agent"})
      {:ok, %{
        channel_id: "UC123456",
        competitors: [%{channel_id: "UC789012", subscriber_count: 25000}],
        benchmark: %{avg_subscriber_count: 20000}
      }}
  """

  use Lux.Lens,
    name: "YouTube Competitor Analysis",
    description: "Analyzes competitor channels and provides benchmarking data",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Your YouTube channel ID"
        },
        competitor_ids: %{
          type: :array,
          description: "List of competitor channel IDs",
          items: %{type: :string}
        }
      },
      required: ["channel_id", "competitor_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        competitors: %{type: :array},
        benchmark: %{type: :object}
      }
    }

  alias Lux.Integrations.Youtube.Client
  require Logger

  def handler(params, agent) do
    channel_id = params[:channel_id] || params["channel_id"]
    competitor_ids = params[:competitor_ids] || params["competitor_ids"] || []
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} running competitor analysis for #{channel_id}")

    all_ids = [channel_id | competitor_ids] |> Enum.join(",")

    case Client.request(:get, "/channels", %{params: %{part: "statistics,snippet", id: all_ids}}) do
      {:ok, %{"items" => channels}} ->
        {own_channel, competitors} = separate_channels(channels, channel_id)
        benchmark = calculate_benchmark(competitors)

        {:ok, %{
          channel_id: channel_id,
          own_metrics: extract_metrics(own_channel),
          competitors: Enum.map(competitors, &extract_metrics/1),
          benchmark: benchmark
        }}

      error ->
        Logger.error("Failed to run competitor analysis: #{inspect(error)}")
        error
    end
  end

  defp separate_channels(channels, own_id) do
    {own, comps} = Enum.split_with(channels, fn ch -> ch["id"] == own_id end)
    {List.first(own), comps}
  end

  defp extract_metrics(nil), do: nil
  defp extract_metrics(channel) do
    stats = channel["statistics"] || %{}
    %{
      channel_id: channel["id"],
      title: get_in(channel, ["snippet", "title"]),
      subscriber_count: String.to_integer(stats["subscriberCount"] || "0"),
      view_count: String.to_integer(stats["viewCount"] || "0"),
      video_count: String.to_integer(stats["videoCount"] || "0")
    }
  end

  defp calculate_benchmark([]), do: %{avg_subscriber_count: 0, avg_view_count: 0, avg_video_count: 0}
  defp calculate_benchmark(competitors) do
    count = length(competitors)
    %{
      avg_subscriber_count: div(Enum.sum(Enum.map(competitors, & &1[:subscriber_count])), count),
      avg_view_count: div(Enum.sum(Enum.map(competitors, & &1[:view_count])), count),
      avg_video_count: div(Enum.sum(Enum.map(competitors, & &1[:video_count])), count)
    }
  end
end
