defmodule Lux.Lenses.YouTube.Videos.VideoAnalyticsLens do
  @moduledoc """
  A lens for fetching YouTube video statistics, snippet metadata, and computing
  deterministic audience engagement scores via YouTube Data API v3 (`/youtube/v3/videos`).
  """

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.ContentIntelligence

  use Lux.Lens,
    name: "YouTube Video Analytics",
    description: "Fetches video statistics and computes audience engagement metrics",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    params: %{"part" => "snippet,statistics,contentDetails"},
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "Comma-separated YouTube video ID(s) to analyze"
        },
        part: %{
          type: :string,
          description: "Resource parts to retrieve (default: snippet,statistics,contentDetails)"
        }
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    videos =
      Enum.map(items, fn item ->
        stats = Map.get(item, "statistics", %{})
        snippet = Map.get(item, "snippet", %{})

        metrics = %{
          view_count: parse_int(stats["viewCount"]),
          like_count: parse_int(stats["likeCount"]),
          comment_count: parse_int(stats["commentCount"])
        }

        intelligence = ContentIntelligence.analyze_engagement(metrics)

        %{
          id: item["id"],
          title: snippet["title"],
          channel_title: snippet["channelTitle"],
          published_at: snippet["publishedAt"],
          tags: Map.get(snippet, "tags", []),
          analytics: intelligence
        }
      end)

    {:ok, %{videos: videos, count: length(videos)}}
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
