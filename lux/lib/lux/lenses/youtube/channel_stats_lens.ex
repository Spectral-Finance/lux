defmodule Lux.Lenses.YouTube.ChannelStatsLens do
  @moduledoc """
  Lens for fetching channel statistics from the YouTube Data API v3.

  Retrieves comprehensive channel metrics including subscriber count,
  total view count, video count, and channel metadata.

  ## API Endpoint

  Uses the `channels.list` endpoint with `statistics` and `snippet` parts.

  ## Examples

      # Fetch stats for Google Developers channel
      Lux.Lenses.YouTube.ChannelStatsLens.focus(%{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw"
      })

      # Fetch stats for multiple channels
      Lux.Lenses.YouTube.ChannelStatsLens.focus(%{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw,UCBR8-60-B28hp2BmDPdntcQ"
      })

  ## Response Format

      %{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        title: "Google Developers",
        description: "Official Google Developers channel...",
        custom_url: "@googledevelopers",
        published_at: "2007-01-01T00:00:00Z",
        statistics: %{
          subscriber_count: 2_500_000,
          view_count: 150_000_000,
          video_count: 1_200,
          hidden_subscriber_count: false
        },
        thumbnails: %{
          default: "https://...",
          medium: "https://...",
          high: "https://..."
        }
      }
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Channel Statistics",
    description: "Fetches channel statistics including subscribers, views, and video count from YouTube",
    url: "#{YouTube.base_url()}/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: %{
      type: :custom,
      auth_function: &YouTube.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube channel ID(s). Multiple IDs can be comma-separated (max 50)",
          pattern: "^UC[a-zA-Z0-9_-]{22}(,UC[a-zA-Z0-9_-]{22})*$"
        },
        part: %{
          type: :string,
          description: "API resource parts to include in response",
          default: "snippet,statistics",
          enum: ["snippet", "snippet,statistics", "snippet,statistics,contentDetails,brandingSettings"]
        },
        for_username: %{
          type: :string,
          description: "YouTube username of the channel (alternative to channel_id)"
        },
        for_handle: %{
          type: :string,
          description: "YouTube handle of the channel (e.g., @googledevelopers)"
        }
      },
      oneOf: [
        %{required: ["channel_id"]},
        %{required: ["for_username"]},
        %{required: ["for_handle"]}
      ]
    }

  require Logger

  @doc """
  Prepares parameters before making the API request.

  Sets the required `part` parameter and validates the channel ID format.
  """
  @impl true
  def before_focus(params) do
    params =
      params
      |> Map.put_new(:part, "snippet,statistics")
      |> Map.update!(:channel_id, fn id ->
        String.trim(id)
      end)

    Logger.debug("YouTube ChannelStatsLens before_focus: #{inspect(params)}")
    params
  end

  @doc """
  Transforms the YouTube API response into a structured format.

  Extracts relevant channel statistics and metadata from the raw API response.

  ## Examples

      iex> after_focus(%{"items" => [%{
      ...>   "id" => "UC123",
      ...>   "snippet" => %{"title" => "Test Channel", "description" => "A test channel"},
      ...>   "statistics" => %{"subscriberCount" => "1000", "viewCount" => "50000", "videoCount" => "10"}
      ...> }]})
      {:ok, %{channels: [%{channel_id: "UC123", title: "Test Channel", ...}]}}

      iex> after_focus(%{"error" => %{"message" => "Channel not found"}})
      {:error, "Channel not found"}

      iex> after_focus(%{"items" => []})
      {:error, "No channel found"}
  """
  @impl true
  def after_focus(%{"items" => [channel | _rest]} = _response) do
    result = transform_channel(channel)
    Logger.info("Successfully fetched channel stats: #{result.title}")
    {:ok, result}
  end

  @impl true
  def after_focus(%{"items" => items}) when is_list(items) and length(items) > 1 do
    channels = Enum.map(items, &transform_channel/1)
    Logger.info("Successfully fetched stats for #{length(channels)} channels")
    {:ok, %{channels: channels}}
  end

  @impl true
  def after_focus(%{"items" => []}) do
    Logger.warning("YouTube ChannelStatsLens: No channels found")
    {:error, "No channel found. Verify the channel ID is correct."}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    Logger.error("YouTube ChannelStatsLens API error: #{message}")
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    Logger.error("YouTube ChannelStatsLens API error: #{error}")
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    Logger.error("YouTube ChannelStatsLens unexpected response: #{inspect(response)}")
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  # Transforms a single channel item from the API response
  defp transform_channel(channel) do
    statistics = Map.get(channel, "statistics", %{})
    snippet = Map.get(channel, "snippet", %{})
    thumbnails = Map.get(snippet, "thumbnails", %{})

    %{
      channel_id: channel["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      thumbnails: %{
        default: thumbnails["default"]["url"],
        medium: thumbnails["medium"]["url"],
        high: thumbnails["high"]["url"]
      },
      statistics: %{
        subscriber_count: parse_integer(statistics["subscriberCount"]),
        view_count: parse_integer(statistics["viewCount"]),
        video_count: parse_integer(statistics["videoCount"]),
        hidden_subscriber_count: statistics["hiddenSubscriberCount"] == true
      }
    }
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end
end
