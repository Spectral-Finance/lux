defmodule Lux.Lenses.YouTube.SearchVideos do
  @moduledoc """
  A lens for searching YouTube videos.
  This lens provides a simple interface for searching videos with:
  - Configurable search query, max results, and ordering
  - Direct YouTube API error propagation
  - Clean response structure

  ## Examples
      iex> SearchVideos.focus(%{
      ...>   q: "elixir programming",
      ...>   max_results: 5
      ...> })
      {:ok, [
        %{
          video_id: "abc123",
          title: "Learn Elixir",
          description: "A great tutorial",
          channel_title: "ElixirCasts",
          published_at: "2024-01-01T00:00:00Z",
          thumbnail_url: "https://i.ytimg.com/vi/abc123/default.jpg"
        }
      ]}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Search YouTube Videos",
    description: "Searches for YouTube videos matching a query",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        q: %{
          type: :string,
          description: "The search query string"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)",
          default: 10
        },
        order: %{
          type: :string,
          description: "Sort order (date, rating, relevance, title, viewCount)",
          default: "relevance"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet"
        },
        type: %{
          type: :string,
          description: "Resource type to search for",
          default: "video"
        }
      },
      required: ["q"]
    }

  @doc """
  Transforms the YouTube API response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    videos = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      %{
        video_id: get_in(item, ["id", "videoId"]) || item["id"],
        title: snippet["title"],
        description: snippet["description"],
        channel_title: snippet["channelTitle"],
        published_at: snippet["publishedAt"],
        thumbnail_url: get_in(snippet, ["thumbnails", "default", "url"])
      }
    end)
    {:ok, videos}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end
end
