defmodule Lux.Lenses.YouTube.Creation.ListPlaylists do
  @moduledoc """
  A lens for listing YouTube playlists for a channel or the authenticated user.

  Fetches playlists from the YouTube Data API v3 /playlists endpoint,
  returning structured playlist metadata including title, item count,
  privacy status, and thumbnail URL.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> ListPlaylists.focus(%{"channel_id" => "UCxxxxxx"})
      {:ok, %{
        playlists: [
          %{
            id: "PLxxxxxx",
            title: "My Playlist",
            description: "A great playlist",
            channel_id: "UCxxxxxx",
            published_at: "2024-01-01T00:00:00Z",
            item_count: 10,
            privacy_status: "public",
            thumbnail_url: "https://..."
          }
        ],
        count: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Playlists",
    description: "Lists playlists for a channel from the YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/playlists",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID to list playlists for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Builds the query parameters for the YouTube playlists endpoint.
  """
  @impl true
  def before_focus(params) do
    channel_id = params["channel_id"] || params[:channel_id]
    max_results = params["max_results"] || params[:max_results] || 25

    {:ok, %{
      "channelId" => channel_id,
      "part" => "snippet,contentDetails,status",
      "maxResults" => max_results
    }}
  end

  @doc """
  Transforms the YouTube API response into structured playlist data.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    playlists =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}
        content = item["contentDetails"] || %{}

        %{
          id: item["id"],
          title: snippet["title"],
          description: snippet["description"],
          channel_id: snippet["channelId"],
          published_at: snippet["publishedAt"],
          item_count: content["itemCount"],
          privacy_status: get_in(item, ["status", "privacyStatus"]),
          thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"])
        }
      end)

    {:ok, %{playlists: playlists, count: length(playlists)}}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end
end
