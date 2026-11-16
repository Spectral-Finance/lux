defmodule Lux.Lenses.YouTube.Channels.ChannelAudienceLens do
  @moduledoc """
  A lens for analyzing a YouTube channel's subscriber base, view velocity,
  and audience growth health via YouTube Data API v3 (`/youtube/v3/channels`).
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Channel Audience Analytics",
    description: "Retrieves channel subscriber statistics, total views, and audience efficiency ratios",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    params: %{"part" => "snippet,statistics"},
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The YouTube channel ID (e.g. 'UC_x5XG1OV2P6uZZ5FSM9Ttw')"
        },
        forUsername: %{
          type: :string,
          description: "Optional legacy YouTube username filter"
        }
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"items" => [channel | _]}) do
    stats = Map.get(channel, "statistics", %{})
    snippet = Map.get(channel, "snippet", %{})

    subscribers = parse_int(stats["subscriberCount"])
    total_views = parse_int(stats["viewCount"])
    video_count = max(parse_int(stats["videoCount"]), 1)

    avg_views_per_video = Float.round(total_views / video_count, 2)

    {:ok,
     %{
       id: channel["id"],
       title: snippet["title"],
       description: snippet["description"],
       subscriber_count: subscribers,
       view_count: total_views,
       video_count: parse_int(stats["videoCount"]),
       avg_views_per_video: avg_views_per_video
     }}
  end

  def after_focus(%{"items" => []}) do
    {:error, :channel_not_found}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(other) do
    {:error, other}
  end

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(_), do: 0
end
