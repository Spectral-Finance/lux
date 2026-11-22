defmodule Lux.Prisms.YouTube.ChannelBenchmarkPrism do
  @moduledoc """
  A prism that benchmarks a YouTube channel against a set of peer channels
  (lux issue #78 — "YouTube Prism implementation", channel intelligence).

  Pure and deterministic: given a `channels.list` resource item and a list of
  peer channel items it reports the channel's standing (rank + percentile) on
  subscribers and total views. Percentile is the fraction of peers the channel
  equals or beats, in `[0, 100]`. Hidden subscriber counts are treated as 0 for
  both the subject and its peers so the comparison stays fair. No network call
  is made here.

  ## Examples
      iex> ChannelBenchmarkPrism.handler(%{
      ...>   channel: %{id: "c1", statistics: %{"subscriberCount" => "1000", "viewCount" => "10000"}},
      ...>   peers: [%{statistics: %{"subscriberCount" => "500", "viewCount" => "5000"}}]
      ...> }, %{})
      {:ok, %{channel_id: "c1", peer_count: 1, subscriber_percentile: 100.0}}
  """

  use Lux.Prism,
    name: "YouTube Channel Benchmark",
    description:
      "Benchmarks a channel against peer channels, reporting rank and percentile standing on subscribers and total views",
    input_schema: %{
      type: :object,
      properties: %{
        channel: %{type: :object, description: "A channels.list resource item"},
        peers: %{type: :array, description: "List of peer channel items", items: %{type: :object}}
      },
      required: ["channel", "peers"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        peer_count: %{type: :integer},
        subscriber_percentile: %{type: :number},
        view_percentile: %{type: :number},
        subscriber_rank: %{type: :integer},
        overall_percentile: %{type: :number}
      },
      required: ["channel_id", "overall_percentile"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    channel = Map.get(params, :channel) || %{}
    peers = params |> Map.get(:peers, []) |> Enum.filter(&is_map/1)

    stats = IntelUtil.section(channel, "statistics")
    subscribers = subscriber_count(stats)
    views = stats |> IntelUtil.get_field("viewCount") |> Util.to_int()

    peer_subs = Enum.map(peers, fn p -> p |> IntelUtil.section("statistics") |> subscriber_count() end)
    peer_views = Enum.map(peers, fn p -> p |> IntelUtil.section("statistics") |> IntelUtil.get_field("viewCount") |> Util.to_int() end)

    sub_percentile = percentile(subscribers, peer_subs)
    view_percentile = percentile(views, peer_views)
    overall = Util.round_to(Util.mean([sub_percentile, view_percentile]), 2)

    # Rank is 1 + number of peers strictly ahead on subscribers.
    sub_rank = 1 + Enum.count(peer_subs, &(&1 > subscribers))

    result = %{
      channel_id: IntelUtil.get_field(channel, "id") || "",
      peer_count: length(peers),
      subscriber_percentile: sub_percentile,
      view_percentile: view_percentile,
      subscriber_rank: sub_rank,
      overall_percentile: overall
    }

    {:ok, result}
  end

  defp subscriber_count(stats) do
    hidden = truthy?(IntelUtil.get_field(stats, "hiddenSubscriberCount"))
    if hidden, do: 0, else: stats |> IntelUtil.get_field("subscriberCount") |> Util.to_int()
  end

  defp percentile(_value, []), do: 100.0

  defp percentile(value, others) do
    beaten = Enum.count(others, &(&1 <= value))
    Util.round_to(Util.safe_div(beaten, length(others)) * 100.0, 2)
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end