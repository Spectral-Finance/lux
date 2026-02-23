defmodule Lux.Lenses.Telegram.Chats.GetChatMember do
  @moduledoc """
  A lens for retrieving information about a specific member of a Telegram chat.

  Returns the membership status and user information for a given user in a chat.

  ## Examples

      iex> GetChatMember.focus(%{chat_id: -1001234567890, user_id: 987654321}, %{})
      {:ok, %{
        status: "member",
        user: %{
          id: 987654321,
          is_bot: false,
          first_name: "John",
          username: "johndoe"
        },
        is_anonymous: false,
        can_send_messages: true
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat Member",
    description: "Retrieves information about a member of a Telegram chat",
    url: "https://api.telegram.org/bot/getChatMember",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target supergroup/channel"
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
    chat_id = params[:chat_id] || params["chat_id"]
    user_id = params[:user_id] || params["user_id"]

    cond do
      is_nil(chat_id) -> {:error, "chat_id is required"}
      is_nil(user_id) -> {:error, "user_id is required"}
      true -> {:ok, %{"chat_id" => chat_id, "user_id" => user_id}}
    end
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => member}) do
    {:ok, %{
      status: member["status"],
      user: member["user"],
      is_anonymous: member["is_anonymous"],
      custom_title: member["custom_title"],
      can_be_edited: member["can_be_edited"],
      can_manage_chat: member["can_manage_chat"],
      can_post_messages: member["can_post_messages"],
      can_edit_messages: member["can_edit_messages"],
      can_delete_messages: member["can_delete_messages"],
      can_manage_video_chats: member["can_manage_video_chats"],
      can_restrict_members: member["can_restrict_members"],
      can_promote_members: member["can_promote_members"],
      can_change_info: member["can_change_info"],
      can_invite_users: member["can_invite_users"],
      can_send_messages: member["can_send_messages"],
      until_date: member["until_date"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
