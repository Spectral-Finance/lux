defmodule Lux.Lenses.Telegram.Chats.GetChat do
  @moduledoc """
  A lens for retrieving information about a Telegram chat (group, supergroup, or channel).

  Returns detailed information about the chat including title, type,
  member count, and permissions.

  ## Examples

      iex> GetChat.focus(%{chat_id: -1001234567890}, %{})
      {:ok, %{
        id: -1001234567890,
        type: "supergroup",
        title: "My Group",
        description: "A great group",
        member_count: 150,
        invite_link: "https://t.me/mygroup"
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat",
    description: "Retrieves detailed information about a Telegram chat, group, or channel",
    url: "https://api.telegram.org/bot/getChat",
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
    case Map.fetch(params, :chat_id) || Map.fetch(params, "chat_id") do
      {:ok, chat_id} ->
        {:ok, %{"chat_id" => chat_id}}

      :error ->
        {:error, "chat_id is required"}
    end
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => chat}) do
    {:ok, %{
      id: chat["id"],
      type: chat["type"],
      title: chat["title"],
      username: chat["username"],
      first_name: chat["first_name"],
      last_name: chat["last_name"],
      description: chat["description"],
      invite_link: chat["invite_link"],
      member_count: chat["member_count"],
      permissions: chat["permissions"],
      photo: chat["photo"],
      pinned_message: chat["pinned_message"],
      slow_mode_delay: chat["slow_mode_delay"],
      linked_chat_id: chat["linked_chat_id"]
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
