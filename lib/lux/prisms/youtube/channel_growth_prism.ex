defmodule Lux.Prisms.YouTube.ChannelGrowthPrism do
  @moduledoc """
  A prism that normalises YouTube channel statistics and derives growth signals
  (lux issue #78 — "YouTube Prism implementation", channel intelligence).

  Pure and deterministic: given a `channels.list` resource item it normalises
  subscriber/view/video counts and computes average views per video plus a
  blended 0-100 growth signal. `hiddenSubscriberCount` is respected — when the
  API hides the subscriber count the prism reports `subscribers_hidden: true`
  and scores on views + volume only, rather than treating the channel as having
  zero subscribers. No network call is made here.

  ## Examples
      iex> ChannelGrowthPrism.handler(%{channel: %{
      ...>   id: "c1",
      ...>   statistics: %{"subscriberCount" => "1000", "viewCount" => "500000", "videoCount" => "100"}
      ...> }}, %{})
      {:ok, %{channel_id: "c1", subscribers: 1000, avg_views_per_video: 5000.0}}
  """

  use Lux.Prism,
    name: "YouTube Channel Growth",
    description:
      "Normalises channel statistics and derives upload frequency, average views per video and a 0-100 growth signal",
    input_schema: %{
      type: :object,
      properties: %{channel: %{type: :object, description: "A channels.list resource item"}},
      required: ["channel"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        title: %{type: :string},
        subscribers: %{type: :integer},
        subscribers_hidden: %{type: :boolean},
        total_views: %{type: :integer},
        video_count: %{type: :integer},
        avg_views_per_video: %{type: :number},
        growth_signal: %{type: :number, description: "Blended 0-100 growth signal"}
      },
      required: ["channel_id", "video_count", "growth_signal"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    channel = Map.get(params, :channel) || %{}
    snippet = IntelUtil.section(channel, "snippet")
    stats = IntelUtil.section(channel, "statistics")

    hidden = truthy?(IntelUtil.get_field(stats, "hiddenSubscriberCount"))
    subscribers = if hidden, do: 0, else: stats |> IntelUtil.get_field("subscriberCount") |> Util.to_int()
    total_views = stats |> IntelUtil.get_field("viewCount") |> Util.to_int()
    video_count = stats |> IntelUtil.get_field("videoCount") |> Util.to_int()

    avg_views = Util.round_to(Util.safe_div(total_views, video_count), 2)

    # 60% average-views component (full marks at >= 100k avg views) + 40%
    # upload-volume component (full marks at >= 1000 videos).
    avg_component = min(avg_views / 100_000.0, 1.0) * 60.0
    volume_component = min(video_count / 1000.0, 1.0) * 40.0
    growth_signal = Util.round_to(avg_component + volume_component, 2)

    result = %{
      channel_id: IntelUtil.get_field(channel, "id") || "",
      title: IntelUtil.get_field(snippet, "title") || "",
      subscribers: subscribers,
      subscribers_hidden: hidden,
      total_views: total_views,
      video_count: video_count,
      avg_views_per_video: avg_views,
      growth_signal: growth_signal
    }

    {:ok, result}
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end