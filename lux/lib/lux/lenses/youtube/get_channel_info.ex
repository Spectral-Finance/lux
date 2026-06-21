defmodule Lux.Lenses.YouTube.GetChannelInfo do
  @moduledoc """
  A lens for fetching information about a YouTube channel.
  This lens provides a simple interface for getting channel details with:
  - Channel ID as the required parameter
  - Configurable parts (snippet, statistics, contentDetails, etc.)
  - Direct YouTube API error propagation
  - Clean response structure

  ## Examples
      iex> GetChannelInfo.focus(%{
      ...>   id: "UCsBjURrPoezykLs9EqgamOA"
      ...> })
      {:ok, %{
        channel_id: "UCsBjURrPoezykLs9EqgamOA",
        title: "Fireship",
        description: "High-intensity code tutorials...",
        subscriber_count: "2000000",
        video_count: "500",
        view_count: "200000000",
        published_at: "2017-01-01T00:00:00Z",
        thumbnail_url: "https://yt3.ggpht.com/..."
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel Info",
    description: "Fetches information about a specific YouTube channel",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The YouTube channel ID"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,statistics,contentDetails"
        }
      },
      required: ["id"]
    }

  @doc """
  Transforms the YouTube API response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    snippet = item["snippet"] || %{}
    statistics = item["statistics"] || %{}

    {:ok, %{
      channel_id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      subscriber_count: statistics["subscriberCount"],
      video_count: statistics["videoCount"],
      view_count: statistics["viewCount"],
      thumbnail_url: get_in(snippet, ["thumbnails", "default", "url"])
    }}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{"message" => "Channel not found"}}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end
end
