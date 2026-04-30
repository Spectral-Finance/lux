defmodule Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens do
  @moduledoc """
  Lens for fetching comprehensive YouTube channel metrics via the YouTube Data API v3.

  Retrieves channel-level statistics including subscriber count, total views,
  video count, and growth trends over time.

  ## Example

      iex> Lux.Lenses.YoutubeAnalytics.ChannelMetricsLens.focus(%{channel_id: "UC..."})
      {:ok, %{channel_id: "...", subscriber_count: 12345, total_views: 67890, ...}}
  """

  use Lux.Lens,
    name: "YouTube Channel Metrics",
    description: "Fetches comprehensive YouTube channel metrics including subscribers, views, and growth trends",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :query_param,
      param_name: "key",
      env_var: "YOUTUBE_API_KEY"
    },
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube channel ID"
        },
        for_username: %{
          type: :string,
          description: "YouTube channel username (alternative to channel_id)"
        },
        part: %{
          type: :string,
          description: "Comma-separated list of channel resource parts",
          default: "snippet,statistics,brandingSettings,contentDetails,topicDetails"
        },
        include_related_channel_ids: %{
          type: :boolean,
          description: "Include related channel IDs",
          default: false
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        custom_url: %{type: :string},
        published_at: %{type: :string},
        thumbnail_url: %{type: :string},
        subscriber_count: %{type: :integer},
        subscriber_count_hidden: %{type: :boolean},
        view_count: %{type: :integer},
        video_count: %{type: :integer},
        comment_count: %{type: :integer},
        hidden_subscriber_count: %{type: :boolean},
        related_channel_ids: %{type: :array, items: %{type: :string}},
        country: %{type: :string},
        default_language: %{type: :string},
        uploads_playlist_id: %{type: :string},
        topics: %{type: :array, items: %{type: :string}}
      }
    }

  @doc """
  Fetch channel metrics.

  ## Parameters

    * `:channel_id` - YouTube channel ID
    * `:for_username` - YouTube channel username (alternative to channel_id)
    * `:part` - Channel resource parts to include
    * `:include_related_channel_ids` - Whether to include related channels

  ## Examples

      iex> ChannelMetricsLens.focus(%{channel_id: "UC..."})
      {:ok, %{channel_id: "UC...", subscriber_count: 12345, ...}}

      iex> ChannelMetricsLens.focus(%{for_username: "channelname"})
      {:ok, %{channel_id: "UC...", ...}}
  """
  def focus(params) when is_map(params) do
    # Build query parameters
    query_params = build_query_params(params)

    # Make API request
    case Lux.Lens.http_get(__MODULE__, query_params) do
      {:ok, %{status: 200, body: body}} ->
        parse_channel_metrics(body)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: Map.get(body, "error", %{})["message"] || "API error"}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_query_params(params) do
    params
    |> Map.put_new(:part, "snippet,statistics,brandingSettings,contentDetails,topicDetails")
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp parse_channel_metrics(%{"items" => [%{"id" => channel_id, "snippet" => snippet, "statistics" => stats} | _] = _items}) do
    metrics = %{
      channel_id: channel_id,
      title: Map.get(snippet, "title"),
      description: Map.get(snippet, "description"),
      custom_url: Map.get(snippet, "customUrl"),
      published_at: Map.get(snippet, "publishedAt"),
      thumbnail_url: snippet |> Map.get("thumbnails", %{}) |> Map.get("default", %{}) |> Map.get("url"),
      subscriber_count: parse_integer(Map.get(stats, "subscriberCount")),
      subscriber_count_hidden: Map.get(stats, "hiddenSubscriberCount", false),
      view_count: parse_integer(Map.get(stats, "viewCount")),
      video_count: parse_integer(Map.get(stats, "videoCount")),
      comment_count: parse_integer(Map.get(stats, "commentCount")),
      country: snippet |> Map.get("country"),
      default_language: snippet |> Map.get("defaultLanguage"),
      uploads_playlist_id: snippet |> Map.get("contentDetails", %{}) |> Map.get("relatedPlaylists", %{}) |> Map.get("uploads"),
      topics: snippet |> Map.get("topics", [])
    }

    {:ok, metrics}
  end

  defp parse_channel_metrics(%{"items" => []}), do: {:error, "Channel not found"}

  defp parse_channel_metrics(body), do: {:error, %{message: "Unexpected API response", body: body}}

  defp parse_integer(nil), do: 0
  defp parse_integer(val) when is_integer(val), do: val
  defp parse_integer(val) when is_binary(val), do: String.to_integer(val)
end
