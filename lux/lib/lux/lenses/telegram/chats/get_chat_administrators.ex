defmodule Lux.Lenses.Telegram.Chats.GetChatAdministrators do
  @moduledoc """
  A lens for retrieving the list of administrators in a Telegram chat.

  Returns an array of ChatMember objects for all administrators in the chat,
  including the creator.

  ## Examples

      iex> GetChatAdministrators.focus(%{chat_id: -1001234567890}, %{})
      {:ok, [
        %{
          status: "creator",
          user: %{id: 111111111, first_name: "Alice", username: "alice"},
          is_anonymous: false,
          custom_title: "Founder"
        },
        %{
          status: "administrator",
          user: %{id: 222222222, first_name: "Bob", username: "bob"},
          can_delete_messages: true,
          can_restrict_members: true
        }
      ]}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat Administrators",
    description: "Retrieves the list of administrators in a Telegram chat or supergroup",
    url: "https://api.telegram.org/bot/getChatAdministrators",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target supergroup/channel"
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def before_focus(params) do
    case params[:chat_id] || params["chat_id"] do
      nil -> {:error, "chat_id is required"}
      chat_id -> {:ok, %{"chat_id" => chat_id}}
    end
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => admins}) when is_list(admins) do
    {:ok, Enum.map(admins, &format_admin/1)}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end

  defp format_admin(admin) do
    %{
      status: admin["status"],
      user: admin["user"],
      is_anonymous: admin["is_anonymous"],
      custom_title: admin["custom_title"],
      can_be_edited: admin["can_be_edited"],
      can_manage_chat: admin["can_manage_chat"],
      can_post_messages: admin["can_post_messages"],
      can_edit_messages: admin["can_edit_messages"],
      can_delete_messages: admin["can_delete_messages"],
      can_manage_video_chats: admin["can_manage_video_chats"],
      can_restrict_members: admin["can_restrict_members"],
      can_promote_members: admin["can_promote_members"],
      can_change_info: admin["can_change_info"],
      can_invite_users: admin["can_invite_users"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
