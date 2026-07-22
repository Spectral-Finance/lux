defmodule Lux.Lenses.Telegram.GetChatMember do
  @moduledoc """
  A lens to fetch information about a specific member of a chat.
  Uses Telegram Bot API endpoint: POST /getChatMember
  """

  use Lux.Lens,
    name: "Get Telegram Chat Member Info",
    description: "Fetches info and membership status of a specific user in a chat",
    url: "https://api.telegram.org/bot/getChatMember",
    method: :post,
    headers: Lux.Integrations.Telegram.headers(),
    auth: Lux.Integrations.Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        user_id: %{
          type: :integer,
          description: "Unique identifier of the target user"
        }
      },
      required: ["chat_id", "user_id"]
    }

  @impl true
  def before_focus(params) do
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    user_id = Map.get(params, :user_id) || Map.get(params, "user_id")
    %{chat_id: chat_id, user_id: user_id}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => member}) do
    {:ok, %{
      status: member["status"],
      user: %{
        id: member["user"]["id"],
        is_bot: member["user"]["is_bot"],
        first_name: member["user"]["first_name"],
        last_name: member["user"]["last_name"] || "",
        username: member["user"]["username"] || ""
      },
      custom_title: member["custom_title"] || "",
      until_date: member["until_date"],
      # Supergroup admin/restrict details
      can_be_edited: member["can_be_edited"],
      can_manage_chat: member["can_manage_chat"],
      can_post_messages: member["can_post_messages"],
      can_edit_messages: member["can_edit_messages"],
      can_delete_messages: member["can_delete_messages"],
      can_restrict_members: member["can_restrict_members"],
      can_promote_members: member["can_promote_members"],
      can_change_info: member["can_change_info"],
      can_invite_users: member["can_invite_users"],
      can_pin_messages: member["can_pin_messages"],
      is_member: member["is_member"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => desc}) do
    {:error, desc}
  end

  def after_focus(other) do
    {:error, "Unexpected response: #{inspect(other)}"}
  end
end
