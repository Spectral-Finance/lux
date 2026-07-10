defmodule Lux.Prisms.YouTube.ModerateComment do
  @moduledoc """
  A prism for moderating a YouTube comment.
  """

  use Lux.Prism,
    name: "Moderate YouTube Comment",
    description: "Sets the moderation status of a YouTube comment",
    input_schema: %{
      type: :object,
      properties: %{
        comment_id: %{
          type: :string,
          description: "The ID of the comment to moderate"
        },
        moderation_status: %{
          type: :string,
          description: "The moderation status to apply (published, heldForReview, likelySpam, rejected)",
          enum: ["published", "heldForReview", "likelySpam", "rejected"]
        },
        ban_author: %{
          type: :boolean,
          description: "Whether to ban the author from the channel",
          default: false
        },
        dry_run: %{
          type: :boolean,
          description: "If true (default), performs a dry-run and returns a mock response without calling YouTube API. Set to false for live API calls.",
          default: true
        }
      },
      required: ["comment_id", "moderation_status"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        moderated: %{
          type: :boolean,
          description: "Whether the moderation was successful"
        }
      },
      required: ["moderated"]
    }

  alias Lux.Integrations.YouTube.Client
  require Logger

  @doc """
  Handles the request to moderate a comment.
  """
  def handler(params, agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    with {:ok, comment_id} <- validate_param(params, :comment_id),
         {:ok, moderation_status} <- validate_param(params, :moderation_status) do
      agent_name = agent[:name] || "Unknown Agent"
      access_token = Map.get(params, :access_token)
      plug = Map.get(params, :plug)
      dry_run = Map.get(params, :dry_run, true)
      ban_author = Map.get(params, :ban_author, false)

      Logger.info("Agent #{agent_name} moderating comment #{comment_id} to #{moderation_status}")

      case Client.request(:post, "/comments/setModerationStatus", %{
        params: %{
          id: comment_id,
          moderationStatus: moderation_status,
          banAuthor: ban_author
        },
        access_token: access_token,
        plug: plug,
        dry_run: dry_run
      }) do
        {:ok, _response} ->
          Logger.info("Successfully moderated comment #{comment_id}")
          {:ok, %{moderated: true}}

        {:error, {status, message}} ->
          error = {status, message}
          Logger.error("Failed to moderate comment: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to moderate comment: #{inspect(error)}")
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
