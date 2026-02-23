defmodule Lux.Lenses.YouTube.Analytics.SearchTrendingTopics do
  @moduledoc """
  A lens for discovering trending topics on YouTube.

  Uses the YouTube Data API v3 /search endpoint with viewCount ordering
  and optional category/region filters to surface trending video topics.
  Returns topics with view counts, trending scores, and metadata useful
  for content strategy.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> SearchTrendingTopics.focus(%{
      ...>   "query" => "elixir programming",
      ...>   "max_results" => 10,
      ...>   "region_code" => "US"
      ...> })
      {:ok, %{
        topics: [%{
          video_id: "abc123",
          title: "Learn Elixir in 1 Hour",
          channel_title: "CodeChannel",
          view_count: 500_000,
          trending_score: 82,
          published_at: "2024-01-15T10:00:00Z"
        }],
        total_results: 50,
        query: "elixir programming"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Search Trending Topics",
    description: "Discovers trending YouTube topics by searching with viewCount ordering and optional filters",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search query to find trending topics"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)",
          minimum: 1,
          maximum: 50,
          default: 10
        },
        region_code: %{
          type: :string,
          description: "ISO 3166-1 alpha-2 country code to filter results (e.g. US, GB)"
        },
        video_category_id: %{
          type: :string,
          description: "YouTube video category ID to filter results"
        },
        published_after: %{
          type: :string,
          description: "Only include videos published after this RFC 3339 timestamp"
        }
      },
      required: ["query"]
    }

  @doc """
  Builds the query parameters for the YouTube search endpoint.
  """
  @impl true
  def before_focus(params) do
    base = %{
      "part" => "snippet",
      "type" => "video",
      "order" => "viewCount",
      "q" => params["query"],
      "maxResults" => params["max_results"] || 10
    }

    base
    |> maybe_put("regionCode", params["region_code"])
    |> maybe_put("videoCategoryId", params["video_category_id"])
    |> maybe_put("publishedAfter", params["published_after"])
    |> then(&{:ok, &1})
  end

  @doc """
  Transforms the YouTube search response into trending topic data.
  """
  @impl true
  def after_focus(%{"items" => items, "pageInfo" => page_info} = response) do
    topics =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        snippet = item["snippet"] || %{}
        %{
          video_id: item["id"]["videoId"],
          title: snippet["title"],
          description: snippet["description"],
          channel_id: snippet["channelId"],
          channel_title: snippet["channelTitle"],
          published_at: snippet["publishedAt"],
          thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
          trending_score: compute_trending_score(index, length(items))
        }
      end)

    {:ok, %{
      topics: topics,
      total_results: page_info["totalResults"] || length(items),
      next_page_token: response["nextPageToken"],
      query: response["query"]
    }}
  end

  def after_focus(%{"items" => []}) do
    {:ok, %{topics: [], total_results: 0}}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp compute_trending_score(index, total) when total > 0 do
    # Score from 100 (top result) down to 10 (last result)
    base = 100
    decrement = if total > 1, do: div(90, total - 1), else: 0
    max(base - index * decrement, 10)
  end

  defp compute_trending_score(_index, _total), do: 50

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
