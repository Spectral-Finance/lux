defmodule Lux.Prisms.Telegram.GroupManagement.PromoteChatMember do
  @moduledoc """
  A prism for promotes or demotes a user in a supergroup or a channel via the Telegram Bot API.

  ## Examples

      iex> PromoteChatMember.handler(%{
      ...>   chat_id: 123_456_789,
...>   user_id: 987_654
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Promote Chat Member",
    description: "Promotes or demotes a user in a supergroup or a channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        user_id: %{
          type: :integer,
          description: "Unique identifier of the target user"
        },
        is_anonymous: %{
          type: :boolean,
          description: "Pass True, if the administrator's presence in the chat is hidden"
        },
        can_manage_chat: %{
          type: :boolean,
          description: "Pass True, if the administrator can access the chat event log, chat statistics, message statistics in channels, see channel members, see anonymous administrators in supergroups and ignore slow mode."
        },
        can_delete_messages: %{
          type: :boolean,
          description: "Pass True, if the administrator can delete messages of other users"
        },
        can_manage_video_chats: %{
          type: :boolean,
          description: "Pass True, if the administrator can manage video chats"
        },
        can_restrict_members: %{
          type: :boolean,
          description: "Pass True, if the administrator can restrict, ban or unban chat members"
        },
        can_promote_members: %{
          type: :boolean,
          description: "Pass True, if the administrator can add new administrators with a subset of their own privileges or demote administrators that they have promoted, directly or indirectly"
        },
        can_change_info: %{
          type: :boolean,
          description: "Pass True, if the administrator can change chat title, photo and other settings"
        },
        can_invite_users: %{
          type: :boolean,
          description: "Pass True, if the administrator can invite new users to the chat"
        },
        can_pin_messages: %{
          type: :boolean,
          description: "Pass True, if the administrator can pin messages"
        },
        can_manage_topics: %{
          type: :boolean,
          description: "Pass True, if the user is allowed to create, rename, close, and reopen forum topics"
        }
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the operation was successful"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["success", "chat_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, _} <- validate_param(params, :user_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to promote member in chat #{chat_id}")

      request_body = Map.take(params, [
        :chat_id, :user_id, :is_anonymous, :can_manage_chat,
        :can_delete_messages, :can_manage_video_chats, :can_restrict_members,
        :can_promote_members, :can_change_info, :can_invite_users,
        :can_pin_messages, :can_manage_topics
      ])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/promoteChatMember", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully completed promote member in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to promote member: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to promote member: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to promote member: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
