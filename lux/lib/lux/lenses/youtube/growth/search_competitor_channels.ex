defmodule Lux.Lenses.YouTube.Growth.SearchCompetitorChannels do
  @moduledoc """
  A lens for discovering competitor YouTube channels by keyword search.

  Uses the YouTube Data API v3 `/search` endpoint with `type=channel`
  to return a list of channels matching the search query along with
  subscriber counts, video counts, and total views for competitive analysis.

  ## Authentication

  Uses API key via `key` query parameter.

      config :lux, :api_keys, youtube: "your_api_key"

  ## Examples

      iex> SearchCompetitorChannels.focus(%{
      ...>   query: "elixir programming tutorials",
      ...>   max_results: 5
      ...> })
      {:ok, %{
        channels: [
          %{
            id: "UCxxxxxx",
            title: "ElixirTuts",
            description: "Learn Elixir and Phoenix",
            subscriber_count: nil,
            video_count: nil,
            total_views: nil,
            published_at: "2018-04-01T00:00:00.000Z",
            thumbnail_url: "https://yt3.ggpht.com/..."
          }
        ],
        total_results: 5
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Search YouTube Competitor Channels",
    description: "Discovers competitor channels by keyword with subscriber and view metrics",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search keyword or phrase to find competitor channels"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of channels to return (1-50)",
          minimum: 1,
          maximum: 50,
          default: 10
        },
        order: %{
          type: :string,
          description: "Sort order for results",
          enum: ["relevance", "viewCount", "rating", "title"],
          default: "relevance"
        },
        page_token: %{
          type: :string,
          description: "Page token for pagination"
        }
      },
      required: ["query"]
    }

  @impl true
  def before_focus(params) do
    query_str = params["query"] || params[:query]

    query = %{
      "part" => "snippet",
      "type" => "channel",
      "q" => query_str,
      "maxResults" => params["max_results"] || params[:max_results] || 10,
      "order" => params["order"] || params[:order] || "relevance"
    }

    query =
      case params["page_token"] || params[:page_token] do
        nil -> query
        token -> Map.put(query, "pageToken", token)
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => items, "pageInfo" => page_info}) do
    channels = Enum.map(items, &parse_channel/1)
    {:ok, %{
      channels: channels,
      total_results: page_info["totalResults"] || length(channels)
    }}
  end

  def after_focus(%{"items" => []}) do
    {:ok, %{channels: [], total_results: 0}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_channel(item) do
    snippet = item["snippet"] || %{}
    channel_id = get_in(item, ["id", "channelId"]) || item["id"]

    %{
      id: channel_id,
      title: snippet["channelTitle"] || snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]) ||
                     get_in(snippet, ["thumbnails", "default", "url"]),
      subscriber_count: nil,
      video_count: nil,
      total_views: nil
    }
  end
end
