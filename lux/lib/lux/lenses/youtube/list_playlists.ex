defmodule Lux.Lenses.YouTube.ListPlaylists do
  @moduledoc """
  A lens for listing playlists from a YouTube channel.
  This lens provides a simple interface for listing playlists with:
  - Channel ID as the required parameter
  - Configurable max results
  - Direct YouTube API error propagation
  - Clean response structure

  ## Examples
      iex> ListPlaylists.focus(%{
      ...>   channel_id: "UCsBjURrPoezykLs9EqgamOA",
      ...>   max_results: 10
      ...> })
      {:ok, [
        %{
          playlist_id: "PLlrATfBNZ7893w5u_HWqh1W",
          title: "Elixir Series",
          description: "A series on Elixir...",
          item_count: 15,
          published_at: "2024-01-01T00:00:00Z",
          thumbnail_url: "https://i.ytimg.com/vi/abc/default.jpg"
        }
      ]}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Playlists",
    description: "Lists playlists from a specific YouTube channel",
    url: "https://www.googleapis.com/youtube/v3/playlists",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        channelId: %{
          type: :string,
          description: "The YouTube channel ID to list playlists from"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (1-50)",
          default: 25
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,contentDetails"
        }
      },
      required: ["channelId"]
    }

  @doc """
  Transforms the YouTube API response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    playlists = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      content_details = item["contentDetails"] || %{}

      %{
        playlist_id: item["id"],
        title: snippet["title"],
        description: snippet["description"],
        channel_title: snippet["channelTitle"],
        published_at: snippet["publishedAt"],
        item_count: content_details["itemCount"],
        thumbnail_url: get_in(snippet, ["thumbnails", "default", "url"])
      }
    end)
    {:ok, playlists}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end
end
