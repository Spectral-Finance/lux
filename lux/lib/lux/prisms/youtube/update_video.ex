defmodule Lux.Prisms.YouTube.UpdateVideo do
  @moduledoc """
  A prism for updating video metadata on YouTube.

  This prism provides a simple interface for updating YouTube video details with:
  - Required parameters (video_id, title)
  - Optional parameters (description, tags, category_id, privacy_status)
  - Direct YouTube API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> UpdateVideo.handler(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   title: "Updated Title",
      ...>   description: "Updated description"
      ...> }, %{name: "Agent"})
      {:ok, %{
        updated: true,
        video_id: "dQw4w9WgXcQ",
        title: "Updated Title"
      }}
  """

  use Lux.Prism,
    name: "Update YouTube Video",
    description: "Updates metadata for a YouTube video",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The ID of the video to update"
        },
        title: %{
          type: :string,
          description: "The new title for the video",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "The new description for the video"
        },
        tags: %{
          type: :array,
          description: "Tags for the video",
          items: %{type: :string}
        },
        category_id: %{
          type: :string,
          description: "The YouTube video category ID"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status (public, private, unlisted)",
          enum: ["public", "private", "unlisted"]
        }
      },
      required: ["video_id", "title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether the video was successfully updated"
        },
        video_id: %{
          type: :string,
          description: "The ID of the updated video"
        },
        title: %{
          type: :string,
          description: "The updated title of the video"
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.YouTube.Client
  require Logger

  @doc """
  Handles the request to update a YouTube video's metadata.

  Returns {:ok, %{updated: true, video_id: id, title: title}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    with {:ok, video_id} <- validate_param(params, :video_id),
         {:ok, title} <- validate_param(params, :title) do
      agent_name = agent[:name] || "Unknown Agent"
      description = Map.get(params, :description, "")
      tags = Map.get(params, :tags, [])
      category_id = Map.get(params, :category_id, "22")
      dry_run = Map.get(params, :dry_run)

      Logger.info("Agent #{agent_name} updating YouTube video: #{video_id}")

      snippet = %{
        title: title,
        description: description,
        tags: tags,
        categoryId: category_id
      }

      body = %{
        id: video_id,
        snippet: snippet
      }

      body = case Map.get(params, :privacy_status) do
        nil -> body
        status -> Map.put(body, :status, %{privacyStatus: status})
      end

      case Client.request(:put, "/videos", %{
        params: %{part: "snippet,status"},
        access_token: Map.get(params, :access_token),
        plug: Map.get(params, :plug),
        dry_run: dry_run,
        json: body
      }) do
        {:ok, %{"id" => vid_id, "snippet" => %{"title" => updated_title}}} ->
          Logger.info("Successfully updated video #{vid_id}")
          {:ok, %{updated: true, video_id: vid_id, title: updated_title}}

        {:error, {status, message}} ->
          error = {status, message}
          Logger.error("Failed to update video #{video_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to update video #{video_id}: #{inspect(error)}")
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
