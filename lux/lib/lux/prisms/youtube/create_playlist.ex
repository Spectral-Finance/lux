defmodule Lux.Prisms.YouTube.CreatePlaylist do
  @moduledoc """
  A prism for creating a playlist on YouTube.

  This prism provides a simple interface for creating YouTube playlists with:
  - Required parameters (title)
  - Optional parameters (description, privacy_status)
  - Direct YouTube API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> CreatePlaylist.handler(%{
      ...>   title: "My Awesome Playlist",
      ...>   description: "A collection of great videos",
      ...>   privacy_status: "public"
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        playlist_id: "PLxyz123",
        title: "My Awesome Playlist",
        privacy_status: "public"
      }}
  """

  use Lux.Prism,
    name: "Create YouTube Playlist",
    description: "Creates a new playlist on YouTube",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The title of the playlist",
          minLength: 1,
          maxLength: 150
        },
        description: %{
          type: :string,
          description: "The description of the playlist"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status (public, private, unlisted)",
          enum: ["public", "private", "unlisted"],
          default: "private"
        }
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the playlist was successfully created"
        },
        playlist_id: %{
          type: :string,
          description: "The ID of the created playlist"
        },
        title: %{
          type: :string,
          description: "The title of the created playlist"
        },
        privacy_status: %{
          type: :string,
          description: "The privacy status of the created playlist"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.YouTube.Client
  require Logger

  @doc """
  Handles the request to create a playlist on YouTube.

  Returns {:ok, %{created: true, playlist_id: id, title: title}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    with {:ok, title} <- validate_param(params, :title) do
      agent_name = agent[:name] || "Unknown Agent"
      description = Map.get(params, :description, "")
      privacy_status = Map.get(params, :privacy_status, "private")
      dry_run = Map.get(params, :dry_run)

      Logger.info("Agent #{agent_name} creating YouTube playlist: #{title}")

      case Client.request(:post, "/playlists", %{
        params: %{part: "snippet,status"},
        access_token: Map.get(params, :access_token),
        plug: Map.get(params, :plug),
        dry_run: dry_run,
        json: %{
          snippet: %{
            title: title,
            description: description
          },
          status: %{
            privacyStatus: privacy_status
          }
        }
      }) do
        {:ok, %{"id" => playlist_id, "snippet" => %{"title" => title}, "status" => %{"privacyStatus" => status}}} ->
          Logger.info("Successfully created playlist #{playlist_id}")
          {:ok, %{created: true, playlist_id: playlist_id, title: title, privacy_status: status}}

        {:error, {status, message}} ->
          error = {status, message}
          Logger.error("Failed to create playlist: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to create playlist: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
