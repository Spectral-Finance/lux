defmodule Lux.Prisms.Telegram.Settings.CreateChatInviteLink do
  @moduledoc """
  A prism to create an additional invite link for a chat.
  Uses Telegram Bot API endpoint: POST /createChatInviteLink
  """

  use Lux.Prism,
    name: "Create Telegram Chat Invite Link",
    description: "Creates an additional invite link for a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        name: %{
          type: :string,
          description: "Invite link name; 0-32 characters"
        },
        expire_date: %{
          type: :integer,
          description: "Point in time (Unix timestamp) when the link will expire"
        },
        member_limit: %{
          type: :integer,
          description: "Maximum number of users that can join simultaneously via this link; 1-99999"
        },
        creates_join_request: %{
          type: :boolean,
          description: "True, if users joining the chat via this link need to be approved by chat administrators"
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        invite_link: %{
          type: :string,
          description: "The created invite link"
        },
        name: %{
          type: :string,
          description: "Name of the invite link"
        },
        creator: %{
          type: :object,
          description: "Creator user object"
        }
      },
      required: ["invite_link"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id) do
      
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating invite link for chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        name: fetch_optional(params, :name),
        expire_date: fetch_optional(params, :expire_date),
        member_limit: fetch_optional(params, :member_limit),
        creates_join_request: fetch_optional(params, :creates_join_request)
      }
      # Remove nil values
      request_body = Enum.filter(request_body, fn {_, v} -> not is_nil(v) end) |> Map.new()

      case Client.request(:post, "/createChatInviteLink", %{json: request_body}) do
        {:ok, %{"ok" => true, "result" => result}} ->
          Logger.info("Successfully created invite link for chat #{chat_id}")
          {:ok, %{
            invite_link: result["invite_link"],
            name: result["name"] || "",
            creator: result["creator"] || %{}
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to create invite link: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to create invite link: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to create invite link: #{inspect(error)}"}
      end
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> {:ok, val}
      :error ->
        case Map.fetch(params, to_string(key)) do
          {:ok, val} -> {:ok, val}
          :error -> {:error, "Missing or invalid #{key}"}
        end
    end
  end

  defp fetch_optional(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> val
      :error -> Map.get(params, to_string(key))
    end
  end
end
