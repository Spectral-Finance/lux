defmodule Lux.Prisms.Telegram.Moderation.PromoteChatMember do
  @moduledoc """
  A prism to promote a user to administrator status in a group or channel.
  Uses Telegram Bot API endpoint: POST /promoteChatMember
  """

  use Lux.Prism,
    name: "Promote Telegram Chat Member",
    description: "Promotes a member to administrator status in a chat or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        user_id: %{
          type: :integer,
          description: "Unique identifier of the target user"
        },
        is_anonymous: %{type: :boolean, description: "Pass True if the administrator's presence in the chat is hidden"},
        can_manage_chat: %{type: :boolean, description: "Pass True if the administrator can access the chat event log"},
        can_post_messages: %{type: :boolean, description: "Pass True if the administrator can create channel posts"},
        can_edit_messages: %{type: :boolean, description: "Pass True if the administrator can edit channel posts"},
        can_delete_messages: %{type: :boolean, description: "Pass True if the administrator can delete messages of other users"},
        can_manage_video_chats: %{type: :boolean, description: "Pass True if the administrator can manage video chats"},
        can_restrict_members: %{type: :boolean, description: "Pass True if the administrator can restrict, ban or unban chat members"},
        can_promote_members: %{type: :boolean, description: "Pass True if the administrator can add new administrators"},
        can_change_info: %{type: :boolean, description: "Pass True if the administrator can change chat title, photo and other settings"},
        can_invite_users: %{type: :boolean, description: "Pass True if the administrator can invite users to the chat"},
        can_pin_messages: %{type: :boolean, description: "Pass True if the administrator can pin messages"},
        can_manage_topics: %{type: :boolean, description: "Pass True if the administrator can create, edit or delete forum topics"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the user was successfully promoted"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, user_id} <- fetch_param(params, :user_id) do
      
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} promoting user #{user_id} in chat #{chat_id}")

      optional_keys = [
        :is_anonymous, :can_manage_chat, :can_post_messages, :can_edit_messages,
        :can_delete_messages, :can_manage_video_chats, :can_restrict_members,
        :can_promote_members, :can_change_info, :can_invite_users, :can_pin_messages,
        :can_manage_topics
      ]

      request_body = Enum.reduce(optional_keys, %{chat_id: chat_id, user_id: user_id}, fn key, acc ->
        case fetch_optional(params, key) do
          nil -> acc
          val -> Map.put(acc, key, val)
        end
      end)

      case Client.request(:post, "/promoteChatMember", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully promoted user #{user_id} in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to promote member: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to promote member: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to promote member: #{inspect(error)}"}
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
