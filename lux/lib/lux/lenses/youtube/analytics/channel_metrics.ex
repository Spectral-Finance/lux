defmodule Lux.Lenses.Youtube.Analytics.ChannelMetrics do
  @moduledoc """
  A lens for tracking YouTube channel performance metrics.

  Collects and analyzes key channel metrics including:
  - Subscriber count and growth
  - Total view count
  - Video count
  - Channel engagement rate

  ## Examples

      iex> ChannelMetrics.handler(%{channel_id: "UC123456"}, %{name: "Agent"})
      {:ok, %{
        channel_id: "UC123456",
        subscriber_count: 15000,
        view_count: 500000,
        video_count: 120,
        engagement_rate: 4.5
      }}
  """

  use Lux.Lens,
    name: "YouTube Channel Metrics",
    description: "Tracks key performance metrics for a YouTube channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        subscriber_count: %{type: :integer},
        view_count: %{type: :integer},
        video_count: %{type: :integer},
        engagement_rate: %{type: :number}
      }
    }

  alias Lux.Integrations.Youtube.Client
  require Logger

  def handler(params, agent) do
    channel_id = params[:channel_id] || params["channel_id"]
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching channel metrics for #{channel_id}")

    case Client.request(:get, "/channels", %{params: %{part: "statistics,snippet", id: channel_id}}) do
      {:ok, %{"items" => [channel | _]}} ->
        stats = channel["statistics"] || %{}
        metrics = %{
          channel_id: channel_id,
          subscriber_count: String.to_integer(stats["subscriberCount"] || "0"),
          view_count: String.to_integer(stats["viewCount"] || "0"),
          video_count: String.to_integer(stats["videoCount"] || "0"),
          engagement_rate: calculate_engagement(stats)
        }
        {:ok, metrics}

      {:ok, %{"items" => []}} ->
        {:error, "Channel not found: #{channel_id}"}

      error ->
        Logger.error("Failed to fetch channel metrics: #{inspect(error)}")
        error
    end
  end

  defp calculate_engagement(%{"subscriberCount" => subs, "viewCount" => views}) do
    subs_int = String.to_integer(subs || "1")
    views_int = String.to_integer(views || "0")
    if subs_int > 0, do: Float.round(views_int / subs_int * 100, 2), else: 0.0
  end
  defp calculate_engagement(_), do: 0.0
end
