defmodule Lux.Lenses.YouTube.Community.GetChannelSections do
  @moduledoc """
  A lens for retrieving YouTube channel sections.

  Fetches the content sections of a YouTube channel using the YouTube Data API v3.
  Channel sections represent playlists, featured channels, and other content
  structures. Useful for:
  - Community structure analysis
  - Engagement campaign planning
  - Cross-platform promotion mapping

  ## Examples

      iex> GetChannelSections.focus(%{channel_id: "UCxxxxxxxxxxxxxx"})
      {:ok, %{
        sections: [
          %{
            id: "section_id",
            channel_id: "UCxxxxxxxxxxxxxx",
            title: "Featured Playlists",
            type: "singlePlaylist",
            position: 0,
            playlist_ids: ["PLxxxxxxxxxx"],
            channel_ids: []
          }
        ],
        count: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel Sections",
    description: "Retrieves channel sections for community structure and engagement analysis",
    url: "https://www.googleapis.com/youtube/v3/channelSections",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the YouTube channel to fetch sections for"
        },
        hl: %{
          type: :string,
          description: "Language for localized section titles (e.g. 'en', 'es')",
          default: "en"
        }
      },
      required: ["channel_id"]
    }

  @impl true
  def before_focus(params) do
    channel_id = params["channel_id"] || params[:channel_id]
    hl = params["hl"] || params[:hl] || "en"

    {:ok,
     %{
       "channelId" => channel_id,
       "part" => "snippet,contentDetails",
       "hl" => hl
     }}
  end

  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    sections =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}
        content = item["contentDetails"] || %{}

        %{
          id: item["id"],
          channel_id: snippet["channelId"],
          title: snippet["title"] || snippet["type"],
          type: snippet["type"],
          position: snippet["position"] || 0,
          playlist_ids: content["playlists"] || [],
          channel_ids: content["channels"] || []
        }
      end)

    {:ok, %{sections: sections, count: length(sections)}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end
