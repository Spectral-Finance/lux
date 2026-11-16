defmodule Lux.Lenses.YouTube.Discovery.TrendingTopicsLens do
  @moduledoc """
  A lens for discovering trending videos, high-velocity search topics, and content
  recommendations on YouTube via `/youtube/v3/search`.
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Trending Topics Discovery",
    description: "Searches high-velocity YouTube videos for a topic and generates content recommendations",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    params: %{
      "part" => "snippet",
      "type" => "video",
      "order" => "viewCount",
      "maxResults" => 10
    },
    schema: %{
      type: :object,
      properties: %{
        q: %{
          type: :string,
          description: "Search topic or keyword phrase to analyze on YouTube"
        },
        regionCode: %{
          type: :string,
          description: "ISO 3166-1 alpha-2 country code (e.g. 'US', 'MX')"
        },
        maxResults: %{
          type: :integer,
          description: "Maximum number of trending results to inspect (1 to 50)"
        }
      },
      required: ["q"]
    }

  @impl true
  def after_focus(%{"items" => items} = body) when is_list(items) do
    videos =
      Enum.map(items, fn item ->
        snippet = Map.get(item, "snippet", %{})
        id_map = Map.get(item, "id", %{})

        %{
          video_id: Map.get(id_map, "videoId") || item["id"],
          title: snippet["title"],
          description: snippet["description"],
          channel_title: snippet["channelTitle"],
          published_at: snippet["publishedAt"]
        }
      end)

    keywords =
      videos
      |> Enum.flat_map(fn v ->
        (v.title || "")
        |> String.downcase()
        |> String.split(~r/[^a-z0-9]+/, trim: true)
      end)
      |> Enum.reject(&(String.length(&1) < 4))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_word, count} -> -count end)
      |> Enum.take(10)
      |> Enum.map(fn {word, _count} -> word end)

    {:ok,
     %{
       trending_videos: videos,
       extracted_keywords: keywords,
       total_results: get_in(body, ["pageInfo", "totalResults"]) || length(videos)
     }}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(other) do
    {:error, other}
  end
end
