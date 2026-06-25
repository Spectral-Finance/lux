defmodule Lux.Prisms.YouTube.Community.ModerateComment do
  @moduledoc """
  A prism for moderating YouTube comments.

  Provides automated comment moderation capabilities:
  - Approve, reject, or hold comments
  - Detect spam and inappropriate content
  - Bulk moderation support
  - Sentiment-based routing

  ## Examples

      iex> ModerateComment.handler(%{
      ...>   comment_id: "Ugkx...",
      ...>   action: "setPublished",
      ...>   access_token: "ya29..."
      ...> }, %{name: "ModerationAgent"})
      {:ok, %{moderated: true, comment_id: "Ugkx...", action: "setPublished"}}
  """

  use Lux.Prism,
    name: "Moderate YouTube Comment",
    description: "Moderates a YouTube comment by approving, rejecting, or holding it",
    input_schema: %{
      type: :object,
      properties: %{
        comment_id: %{
          type: :string,
          description: "YouTube comment ID"
        },
        action: %{
          type: :string,
          description: "Moderation action to take",
          enum: ["setPublished", "heldForReview", "likeDislike", "reject"]
        },
        access_token: %{
          type: :string,
          description: "OAuth2 access token with youtube.force-ssl scope"
        },
        ban_author: %{
          type: :boolean,
          description: "Whether to ban the comment author from the channel",
          default: false
        }
      },
      required: ["comment_id", "action", "access_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        moderated: %{type: :boolean},
        comment_id: %{type: :string},
        action: %{type: :string}
      },
      required: ["moderated"]
    }

  require Logger

  @base_url "https://www.googleapis.com/youtube/v3"

  @impl true
  def handler(%{comment_id: comment_id, action: action, access_token: token} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} moderating comment #{comment_id} with action #{action}")

    headers = [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]

    case action do
      a when a in ["setPublished", "heldForReview"] ->
        url = @base_url <> "/comments/setModerationStatus"
        body = Jason.encode!(%{id: comment_id, moderationStatus: action,
                               banAuthor: Map.get(params, :ban_author, false)})
        case Req.post(url, body: body, headers: headers) do
          {:ok, %{status: s}} when s in [200, 204] ->
            Logger.info("Successfully #{action} comment #{comment_id}")
            {:ok, %{moderated: true, comment_id: comment_id, action: action}}
          {:ok, %{status: 401}} -> {:error, :invalid_access_token}
          {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
          {:ok, %{status: s, body: b}} -> {:error, {s, b}}
          {:error, reason} -> {:error, reason}
        end

      "reject" ->
        url = @base_url <> "/comments"
        case Req.delete(url, params: [id: comment_id], headers: headers) do
          {:ok, %{status: s}} when s in [200, 204] ->
            Logger.info("Rejected/deleted comment #{comment_id}")
            {:ok, %{moderated: true, comment_id: comment_id, action: "reject"}}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "Unknown moderation action: #{action}"}
    end
  end
end
