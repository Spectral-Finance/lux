defmodule Lux.Lenses.YouTube.Videos.ListVideos do
  @moduledoc """
  A lens for listing videos from a YouTube channel.

  Supports filtering by channel, search keywords, video status, and more.

  ## Parameters

  - `channel_id`: Filter by specific channel (uses configured channel if omitted)
  - `part`: Fields to retrieve (snippet, contentDetails, status, statistics)
  - `max_results`: Max videos to return (1-50, default 10)
  - `order`: Sort order (date, rating, relevance, title, videoCount, viewCount)
  - `type`: Resource type (video, channel, playlist)
  - `video_type`: Filter by video type (episode, live, series)
  - `on_behalf_of_content_owner`: YouTube partner ID
  - `published_before`/`published_after`: ISO 8601 date filters
  - `chart`: Popular charts (mostPopular, trending)

  ## Examples

      # List channel videos
      iex> ListVideos.focus(%{
      ...>   channel_id: "UCxxxxxxxxxxxxxxxxxxxx",
      ...>   max_results: 10,
      ...>   order: "date"
      ...> })
      {:ok, [%{id: "...", title: "...", published_at: "...", ...}]}

      # Search channel for specific content
      iex> ListVideos.focus(%{
      ...>   channel_id: "UCxxxxxxxxxxxxxxxxxxxx",
      ...>   q: "tutorial",
      ...>   max_results: 5
      ...> })
      {:ok, [...]}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Videos",
    description: "Lists videos from a YouTube channel or search results",
    url: "#{YouTube.api_base_url()}/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Channel ID to filter videos (uses configured channel if omitted)"
        },
        part: %{
          type: :string,
          description: "Comma-separated list of video resource parts",
          default: "snippet,contentDetails,status,statistics",
          enum: ["snippet", "contentDetails", "status", "statistics", "snippet,contentDetails", "snippet,contentDetails,status,statistics"]
        },
        max_results: %{
          type: :integer,
          description: "Max results to return (1-50)",
          minimum: 1,
          maximum: 50,
          default: 10
        },
        order: %{
          type: :string,
          description: "Sort order",
          enum: ["date", "rating", "relevance", "title", "videoCount", "viewCount"],
          default: "date"
        },
        type: %{
          type: :string,
          description: "Resource type to filter by",
          default: "video",
          enum: ["video", "channel", "playlist"]
        },
        video_type: %{
          type: :string,
          description: "Filter by video type",
          enum: ["episode", "live", "series"]
        },
        published_before: %{
          type: :string,
          description: "Filter videos published before this ISO 8601 date"
        },
        published_after: %{
          type: :string,
          description: "Filter videos published after this ISO 8601 date"
        },
        q: %{
          type: :string,
          description: "Search query to filter videos by title/description"
        },
        chart: %{
          type: :string,
          description: "Popular charts to retrieve",
          enum: ["mostPopular", "trending"]
        },
        region_code: %{
          type: :string,
          description: "ISO 3166-2 country code for regional results"
        },
        hl: %{
          type: :string,
          description: "Locale for results (e.g., 'en', 'zh-CN')"
        },
        page_token: %{
          type: :string,
          description: "Pagination token from a previous response"
        },
        on_behalf_of_content_owner: %{
          type: :string,
          description: "YouTube content owner ID for partner accounts"
        }
      },
      required: []
    }

  @impl true
  def before_focus(params) do
    channel_id = Map.get(params, :channel_id, YouTube.channel_id())
    max_results = Map.get(params, :max_results, 10)
    part = Map.get(params, :part, "snippet,contentDetails,status,statistics")
    order = Map.get(params, :order, "date")
    type = Map.get(params, :type, "video")

    query_params =
      [{"part", part}, {"maxResults", max_results}, {"type", type}]
      |> maybe_add("order", Map.get(params, :order))
      |> maybe_add("videoType", Map.get(params, :video_type))
      |> maybe_add("publishedBefore", Map.get(params, :published_before))
      |> maybe_add("publishedAfter", Map.get(params, :published_after))
      |> maybe_add("q", Map.get(params, :q))
      |> maybe_add("chart", Map.get(params, :chart))
      |> maybe_add("regionCode", Map.get(params, :region_code))
      |> maybe_add("hl", Map.get(params, :hl))
      |> maybe_add("pageToken", Map.get(params, :page_token))
      |> maybe_add("onBehalfOfContentOwner", Map.get(params, :on_behalf_of_content_owner))

    url = if channel_id do
      "#{YouTube.api_base_url()}/search?channelId=#{channel_id}&#{URI.encode_query(query_params)}"
    else
      "#{YouTube.api_base_url()}/videos?#{URI.encode_query(query_params)}"
    end

    %{url: url, params: query_params}
  end

  @doc """
  Transforms the YouTube API search/list response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => items} = response) do
    videos = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      content_details = item["contentDetails"] || %{}
      status = item["status"] || %{}
      statistics = item["statistics"] || %{}

      %{
        id: item["id"] || get_in(snippet, ["resourceId", "videoId"]),
        title: snippet["title"],
        description: snippet["description"],
        published_at: snippet["publishedAt"],
        channel_id: snippet["channelId"],
        channel_title: snippet["channelTitle"],
        thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
        duration: Map.get(content_details, "duration"),
        definition: Map.get(content_details, "definition"),
        caption: Map.get(content_details, "caption"),
        licensed_content: Map.get(content_details, "licensedContent"),
        privacy_status: Map.get(status, "privacyStatus"),
        embeddable: Map.get(status, "embeddable"),
        subscriber_count: get_in(statistics, ["subscriberCount"]),
        video_count: get_in(statistics, ["videoCount"]),
        view_count: get_in(statistics, ["viewCount"]),
        comment_count: get_in(statistics, ["commentCount"]),
        like_count: get_in(statistics, ["likeCount"]),
        favorite_count: get_in(statistics, ["favoriteCount"])
      }
    end)

    result = %{videos: videos}

    next_token = response["nextPageToken"]
    if next_token, do: Map.put(result, :next_page_token, next_token), else: result
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value), do: params ++ [{Atom.to_string(key), to_string(value)}]

  defp get_in(data, []), do: nil
  defp get_in(data, [key]), do: Map.get(data, key)
  defp get_in(data, [first | rest]), do: get_in(Map.get(data, first), rest)
end
