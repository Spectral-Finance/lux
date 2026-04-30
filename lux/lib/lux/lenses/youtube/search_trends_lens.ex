defmodule Lux.Lenses.YouTube.SearchTrendsLens do
  @moduledoc """
  Lens for searching YouTube content and discovering trending videos.

  Uses the YouTube Data API v3 `search.list` endpoint to find videos,
  channels, and playlists matching specific queries. Supports ordering
  by relevance, date, view count, and rating.

  ## API Endpoint

  Uses the `search.list` endpoint with `snippet` part.

  ## Examples

      # Search for trending Elixir content
      Lux.Lenses.YouTube.SearchTrendsLens.focus(%{
        query: "elixir programming tutorial",
        max_results: 10,
        order: "relevance"
      })

      # Find recently uploaded videos about a topic
      Lux.Lenses.YouTube.SearchTrendsLens.focus(%{
        query: "web3 development",
        max_results: 25,
        order: "date",
        type: "video"
      })

      # Find most viewed videos
      Lux.Lenses.YouTube.SearchTrendsLens.focus(%{
        query: "machine learning",
        max_results: 50,
        order: "viewCount",
        type: "video",
        published_after: "2024-01-01T00:00:00Z"
      })

  ## Response Format

      %{
        results: [
          %{
            video_id: "abc123",
            title: "Video Title",
            description: "Video description...",
            channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
            channel_title: "Channel Name",
            published_at: "2024-01-15T12:00:00Z",
            thumbnails: %{
              default: "https://...",
              medium: "https://...",
              high: "https://..."
            }
          }
        ],
        next_page_token: "CAUQAA",
        total_results: 1000,
        region_code: "US"
      }
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Search Trends",
    description: "Searches YouTube for trending content, videos, and channels by query",
    url: "#{YouTube.base_url()}/search",
    method: :get,
    headers: YouTube.headers(),
    auth: %{
      type: :custom,
      auth_function: &YouTube.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Text query to search for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)",
          default: 10,
          minimum: 1,
          maximum: 50
        },
        order: %{
          type: :string,
          description: "Sort order for results",
          default: "relevance",
          enum: ["relevance", "date", "viewCount", "rating", "title"]
        },
        type: %{
          type: :string,
          description: "Type of resource to search for",
          default: "video",
          enum: ["video", "channel", "playlist", "movie"]
        },
        region_code: %{
          type: :string,
          description: "ISO 3166-1 alpha-2 country code for region-specific results",
          pattern: "^[A-Z]{2}$"
        },
        published_after: %{
          type: :string,
          description: "Only include videos published after this date (ISO 8601)",
          format: "date-time"
        },
        published_before: %{
          type: :string,
          description: "Only include videos published before this date (ISO 8601)",
          format: "date-time"
        },
        safe_search: %{
          type: :string,
          description: "Safe search filtering level",
          default: "moderate",
          enum: ["moderate", "strict", "none"]
        },
        video_duration: %{
          type: :string,
          description: "Filter by video duration",
          enum: ["short", "medium", "long"]
        },
        video_definition: %{
          type: :string,
          description: "Filter by video definition",
          enum: ["high", "standard"]
        },
        video_caption: %{
          type: :string,
          description: "Filter by caption availability",
          enum: ["closedCaption", "none"]
        },
        channel_id: %{
          type: :string,
          description: "Restrict search to a specific channel"
        },
        page_token: %{
          type: :string,
          description: "Token for pagination to get next page of results"
        }
      },
      required: ["query"]
    }

  require Logger

  @doc """
  Prepares parameters before making the API request.

  Sets default values and validates parameters.
  """
  @impl true
  def before_focus(params) do
    params =
      params
      |> Map.put_new(:part, "snippet")
      |> Map.put_new(:max_results, 10)
      |> Map.put_new(:order, "relevance")
      |> Map.put_new(:type, "video")
      |> Map.update!(:query, fn q ->
        String.trim(q)
      end)
      |> Enum.filter(fn
        {_key, nil} -> false
        {_key, ""} -> false
        _ -> true
      end)
      |> Map.new()

    Logger.debug("YouTube SearchTrendsLens before_focus: #{inspect(params)}")
    params
  end

  @doc """
  Transforms the YouTube API response into a structured format.

  Extracts relevant search result data and formats it for consumption.

  ## Examples

      iex> after_focus(%{
      ...>   "items" => [%{
      ...>     "id" => %{"videoId" => "abc123"},
      ...>     "snippet" => %{"title" => "Test Video", "channelTitle" => "Test Channel"}
      ...>   }],
      ...>   "nextPageToken" => "CAUQAA",
      ...>   "pageInfo" => %{"totalResults" => 1000, "resultsPerPage" => 10}
      ...> })
      {:ok, %{results: [%{video_id: "abc123", ...}], next_page_token: "CAUQAA", total_results: 1000}}

      iex> after_focus(%{"error" => %{"message" => "Invalid query"}})
      {:error, "Invalid query"}
  """
  @impl true
  def after_focus(%{"items" => items} = response) do
    results = Enum.map(items, &transform_search_item/1)
    next_page_token = response["nextPageToken"]
    page_info = Map.get(response, "pageInfo", %{})
    region_code = response["regionCode"]

    Logger.info("Successfully fetched #{length(results)} search results")

    {:ok,
     %{
       results: results,
       next_page_token: next_page_token,
       total_results: Map.get(page_info, "totalResults", 0),
       results_per_page: Map.get(page_info, "resultsPerPage", 0),
       region_code: region_code
     }}
  end

  @impl true
  def after_focus(%{"items" => []}) do
    Logger.warning("YouTube SearchTrendsLens: No results found")
    {:ok, %{results: [], next_page_token: nil, total_results: 0, results_per_page: 0}}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    Logger.error("YouTube SearchTrendsLens API error: #{message}")
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    Logger.error("YouTube SearchTrendsLens API error: #{error}")
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    Logger.error("YouTube SearchTrendsLens unexpected response: #{inspect(response)}")
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  # Transforms a single search result item
  defp transform_search_item(item) do
    snippet = Map.get(item, "snippet", %{})
    id = Map.get(item, "id", %{})

    # Get the appropriate ID based on result type
    resource_id =
      case id do
        %{"videoId" => video_id} -> video_id
        %{"channelId" => channel_id} -> channel_id
        %{"playlistId" => playlist_id} -> playlist_id
        _ -> Map.get(id, "id", "")
      end

    thumbnails = Map.get(snippet, "thumbnails", %{})

    %{
      resource_id: resource_id,
      resource_type: Map.get(id, "kind", "") |> extract_resource_type(),
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      thumbnails: %{
        default: thumbnails["default"]["url"],
        medium: thumbnails["medium"]["url"],
        high: thumbnails["high"]["url"]
      }
    }
  rescue
    _e ->
      %{
        resource_id: "",
        resource_type: "unknown",
        title: snippet["title"] || "Unknown",
        description: snippet["description"] || "",
        channel_id: snippet["channelId"] || "",
        channel_title: snippet["channelTitle"] || "",
        published_at: snippet["publishedAt"] || "",
        thumbnails: %{}
      }
  end

  defp extract_resource_type(kind) do
    case kind do
      "youtube#video" -> "video"
      "youtube#channel" -> "channel"
      "youtube#playlist" -> "playlist"
      _ -> "unknown"
    end
  end
end
