defmodule Lux.Prisms.YouTube.ChannelStats do
  @moduledoc """
  A prism that turns a raw `channels.list` item (YouTube Data API v3) into a
  typed channel-statistics record (lux issue #73 — "YouTube Prism
  implementation").

  Pure and deterministic: given a channel resource as returned by
  `channels.list?part=snippet,statistics,contentDetails` it returns the
  subscriber / view / video counts (coerced from YouTube's string encoding),
  the uploads playlist id, the published year, and the average views per video.
  No network call is made here — callers fetch the channel via their YouTube
  client and pass the parsed map in.

  ## Examples
      iex> ChannelStats.handler(%{
      ...>   id: "UC1",
      ...>   snippet: %{title: "My Channel", publishedAt: "2015-06-01T00:00:00Z"},
      ...>   statistics: %{subscriberCount: "1000", viewCount: "50000", videoCount: "20"},
      ...>   contentDetails: %{relatedPlaylists: %{uploads: "UU1"}}
      ...> }, %{name: "Agent"})
      {:ok, %{channel_id: "UC1", subscriber_count: 1000, avg_views_per_video: 2500.0}}
  """

  use Lux.Prism,
    name: "YouTube Channel Stats",
    description:
      "Normalises a YouTube channels.list resource into typed channel statistics with uploads playlist and averages",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The channel ID"},
        snippet: %{
          type: :object,
          description: "channels.list snippet (title, customUrl, publishedAt)"
        },
        statistics: %{
          type: :object,
          description:
            "channels.list statistics (subscriberCount, viewCount, videoCount as strings)"
        },
        contentDetails: %{
          type: :object,
          description: "channels.list contentDetails (relatedPlaylists.uploads)"
        }
      },
      required: ["id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "The channel ID"},
        title: %{type: :string, description: "The channel title"},
        custom_url: %{type: :string, description: "The channel custom URL"},
        published_at: %{type: :string, description: "ISO-8601 publish timestamp"},
        subscriber_count: %{type: :integer, description: "Subscriber count"},
        view_count: %{type: :integer, description: "Lifetime view count"},
        video_count: %{type: :integer, description: "Number of public videos"},
        uploads_playlist_id: %{type: :string, description: "The uploads playlist ID"},
        avg_views_per_video: %{type: :number, description: "view_count / video_count"},
        published_year: %{type: :integer, description: "Publish year (0 if unknown)"}
      },
      required: ["channel_id", "subscriber_count", "view_count", "video_count"]
    }

  alias Lux.Prisms.YouTube.DataUtil

  def handler(params, _agent) do
    snippet = Map.get(params, :snippet, %{})
    stats = Map.get(params, :statistics, %{})
    details = Map.get(params, :contentDetails, %{})

    subscribers = DataUtil.to_int(Map.get(stats, :subscriberCount))
    views = DataUtil.to_int(Map.get(stats, :viewCount))
    videos = DataUtil.to_int(Map.get(stats, :videoCount))

    uploads =
      details
      |> Map.get(:relatedPlaylists, %{})
      |> Map.get(:uploads, "")

    result = %{
      channel_id: Map.get(params, :id, ""),
      title: Map.get(snippet, :title, ""),
      custom_url: Map.get(snippet, :customUrl, ""),
      published_at: Map.get(snippet, :publishedAt, ""),
      subscriber_count: subscribers,
      view_count: views,
      video_count: videos,
      uploads_playlist_id: uploads,
      avg_views_per_video: DataUtil.round_to(DataUtil.safe_div(views, videos), 2),
      published_year: published_year(Map.get(snippet, :publishedAt))
    }

    {:ok, result}
  end

  defp published_year(nil), do: 0
  defp published_year(""), do: 0

  defp published_year(timestamp) when is_binary(timestamp) do
    case Regex.run(~r/^(\d{4})/, timestamp) do
      [_, year] -> String.to_integer(year)
      _ -> 0
    end
  end

  defp published_year(_), do: 0
end
