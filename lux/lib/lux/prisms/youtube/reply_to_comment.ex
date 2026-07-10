defmodule Lux.Prisms.YouTube.ReplyToComment do
  @moduledoc """
  A prism for replying to an existing YouTube comment.
  """

  use Lux.Prism,
    name: "Reply to YouTube Comment",
    description: "Replies to an existing YouTube comment thread",
    input_schema: %{
      type: :object,
      properties: %{
        parent_id: %{
          type: :string,
          description: "The ID of the comment thread to reply to"
        },
        text: %{
          type: :string,
          description: "The text of the reply"
        },
        dry_run: %{
          type: :boolean,
          description: "If true (default), performs a dry-run and returns a mock response without calling YouTube API. Set to false for live API calls.",
          default: true
        }
      },
      required: ["parent_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        replied: %{
          type: :boolean,
          description: "Whether the reply was successful"
        },
        reply_id: %{
          type: :string,
          description: "The ID of the generated reply"
        }
      },
      required: ["replied"]
    }

  alias Lux.Integrations.YouTube.Client
  require Logger

  @doc """
  Handles the request to reply to a comment.
  """
  def handler(params, agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    with {:ok, parent_id} <- validate_param(params, :parent_id),
         {:ok, text} <- validate_param(params, :text) do
      agent_name = agent[:name] || "Unknown Agent"
      access_token = Map.get(params, :access_token)
      plug = Map.get(params, :plug)
      dry_run = Map.get(params, :dry_run, true)

      Logger.info("Agent #{agent_name} replying to comment #{parent_id}")

      case Client.request(:post, "/comments", %{
        params: %{part: "snippet"},
        access_token: access_token,
        plug: plug,
        dry_run: dry_run,
        json: %{
          snippet: %{
            parentId: parent_id,
            textOriginal: text
          }
        }
      }) do
        {:ok, %{"id" => reply_id}} ->
          Logger.info("Successfully replied to comment #{parent_id}")
          {:ok, %{replied: true, reply_id: reply_id}}

        {:error, {status, message}} ->
          error = {status, message}
          Logger.error("Failed to reply to comment: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to reply to comment: #{inspect(error)}")
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
