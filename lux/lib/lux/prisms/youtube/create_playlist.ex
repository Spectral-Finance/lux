defmodule Lux.Prisms.YouTube.CreatePlaylist do
  @moduledoc """
  A prism for creating a YouTube playlist.

  Generates the structured API request payload and metadata for creating
  a YouTube playlist. Because creating playlists requires OAuth 2.0
  authentication (write scope), this prism returns the full request
  structure including the endpoint, required scopes, and the playlist
  data that would be created — enabling agents to prepare and submit
  the request with the appropriate credentials.

  ## Examples

      iex> CreatePlaylist.handler(%{
      ...>   "title" => "My Awesome Playlist",
      ...>   "description" => "A curated collection of videos",
      ...>   "privacy_status" => "public",
      ...>   "tags" => ["elixir", "programming"]
      ...> }, %{})
      {:ok, %{
        playlist_data: %{
          snippet: %{title: "My Awesome Playlist", description: "...", tags: [...]},
          status: %{privacy_status: "public"}
        },
        api_endpoint: "https://www.googleapis.com/youtube/v3/playlists",
        required_scopes: ["https://www.googleapis.com/auth/youtube"],
        http_method: "POST",
        query_params: %{part: "snippet,status"}
      }}
  """

  use Lux.Prism,
    name: "Create YouTube Playlist",
    description: "Prepares a YouTube playlist creation request with structured payload and required OAuth scopes",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The playlist title (max 100 characters)"
        },
        description: %{
          type: :string,
          description: "The playlist description (max 5000 characters)"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status: 'public', 'private', or 'unlisted'"
        },
        tags: %{
          type: :array,
          description: "List of keyword tags for the playlist",
          items: %{type: :string}
        },
        default_language: %{
          type: :string,
          description: "BCP-47 language code for the playlist content (e.g., 'en', 'es')"
        }
      },
      required: ["title", "privacy_status"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        playlist_data: %{
          type: :object,
          description: "The playlist resource body to POST to the YouTube API"
        },
        api_endpoint: %{
          type: :string,
          description: "The YouTube Data API endpoint for playlist creation"
        },
        required_scopes: %{
          type: :array,
          description: "OAuth 2.0 scopes required to create the playlist",
          items: %{type: :string}
        },
        http_method: %{
          type: :string,
          description: "HTTP method to use when calling the API"
        },
        query_params: %{
          type: :object,
          description: "Query parameters to include in the API request"
        }
      },
      required: ["playlist_data", "api_endpoint", "required_scopes", "http_method"]
    }

  require Logger

  @youtube_playlists_endpoint "https://www.googleapis.com/youtube/v3/playlists"
  @required_scopes ["https://www.googleapis.com/auth/youtube"]

  @doc """
  Prepares the playlist creation request structure.
  """
  @impl true
  def handler(params, agent) do
    with {:ok, title} <- validate_title(params),
         {:ok, privacy_status} <- validate_privacy_status(params) do
      description = params["description"] || params[:description] || ""
      tags = params["tags"] || params[:tags] || []
      default_language = params["default_language"] || params[:default_language]

      agent_name = get_in(agent, [:agent, :name]) || get_in(agent, ["agent", "name"]) || "Unknown"
      Logger.info("Agent #{agent_name} preparing playlist creation: #{title} (#{privacy_status})")

      snippet =
        %{
          title: title,
          description: description,
          tags: tags
        }
        |> maybe_put(:default_language, default_language)

      playlist_data = %{
        snippet: snippet,
        status: %{privacy_status: privacy_status}
      }

      {:ok, %{
        playlist_data: playlist_data,
        api_endpoint: @youtube_playlists_endpoint,
        required_scopes: @required_scopes,
        http_method: "POST",
        query_params: %{part: "snippet,status"}
      }}
    end
  end

  defp validate_title(params) do
    case params["title"] || params[:title] do
      nil -> {:error, "Missing required parameter: title"}
      "" -> {:error, "Title cannot be empty"}
      title when byte_size(title) > 100 -> {:error, "Title exceeds 100 character limit"}
      title -> {:ok, title}
    end
  end

  defp validate_privacy_status(params) do
    status = params["privacy_status"] || params[:privacy_status]

    case status do
      s when s in ["public", "private", "unlisted"] -> {:ok, s}
      nil -> {:error, "Missing required parameter: privacy_status"}
      invalid -> {:error, "Invalid privacy_status '#{invalid}'. Must be 'public', 'private', or 'unlisted'"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
