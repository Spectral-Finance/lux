defmodule Lux.Prisms.YouTube.VideoStats do
  @moduledoc """
  A prism that turns a raw `videos.list` item (YouTube Data API v3) into a
  typed, normalised video-statistics record (lux issue #73 — "YouTube Prism
  implementation").

  Pure and deterministic: given a single video resource as returned by
  `videos.list?part=snippet,statistics,contentDetails` it returns view / like /
  comment counts (coerced from YouTube's string encoding), the like ratio and
  comment ratio, the ISO-8601 duration in seconds, and the published year. No
  network call is made here — callers fetch the video via their YouTube client
  and pass the parsed map in, which keeps the prism unit-testable and
  side-effect free.

  ## Examples
      iex> VideoStats.handler(%{
      ...>   id: "abc",
      ...>   snippet: %{title: "Hi", publishedAt: "2024-03-01T12:00:00Z"},
      ...>   statistics: %{viewCount: "1000", likeCount: "100", commentCount: "10"},
      ...>   contentDetails: %{duration: "PT1H2M3S"}
      ...> }, %{name: "Agent"})
      {:ok, %{video_id: "abc", view_count: 1000, like_count: 100,
             comment_count: 10, like_ratio: 0.1, duration_seconds: 3723}}
  """

  use Lux.Prism,
    name: "YouTube Video Stats",
    description:
      "Normalises a YouTube videos.list resource into typed video statistics with ratios and duration",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The video ID"},
        snippet: %{
          type: :object,
          description: "videos.list snippet (title, channelTitle, publishedAt)"
        },
        statistics: %{
          type: :object,
          description: "videos.list statistics (viewCount, likeCount, commentCount as strings)"
        },
        contentDetails: %{
          type: :object,
          description: "videos.list contentDetails (duration as ISO-8601)"
        }
      },
      required: ["id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string, description: "The video ID"},
        title: %{type: :string, description: "The video title"},
        channel_title: %{type: :string, description: "The owning channel title"},
        published_at: %{type: :string, description: "ISO-8601 publish timestamp"},
        view_count: %{type: :integer, description: "View count"},
        like_count: %{type: :integer, description: "Like count"},
        comment_count: %{type: :integer, description: "Comment count"},
        like_ratio: %{type: :number, description: "likes / views in [0, 1]"},
        comment_ratio: %{type: :number, description: "comments / views in [0, 1]"},
        duration_seconds: %{type: :integer, description: "Duration in seconds"},
        published_year: %{type: :integer, description: "Publish year (0 if unknown)"}
      },
      required: ["video_id", "view_count", "like_count", "comment_count"]
    }

  alias Lux.Prisms.YouTube.DataUtil

  def handler(params, _agent) do
    snippet = Map.get(params, :snippet, %{})
    stats = Map.get(params, :statistics, %{})
    details = Map.get(params, :contentDetails, %{})

    views = DataUtil.to_int(Map.get(stats, :viewCount))
    likes = DataUtil.to_int(Map.get(stats, :likeCount))
    comments = DataUtil.to_int(Map.get(stats, :commentCount))

    result = %{
      video_id: Map.get(params, :id, ""),
      title: Map.get(snippet, :title, ""),
      channel_title: Map.get(snippet, :channelTitle, ""),
      published_at: Map.get(snippet, :publishedAt, ""),
      view_count: views,
      like_count: likes,
      comment_count: comments,
      like_ratio: DataUtil.round_to(DataUtil.safe_div(likes, views), 4),
      comment_ratio: DataUtil.round_to(DataUtil.safe_div(comments, views), 4),
      duration_seconds: DataUtil.iso8601_to_seconds(Map.get(details, :duration)),
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
