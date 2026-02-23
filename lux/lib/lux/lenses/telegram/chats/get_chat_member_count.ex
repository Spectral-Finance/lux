defmodule Lux.Lenses.Telegram.Chats.GetChatMemberCount do
  @moduledoc """
  A lens for retrieving the number of members in a Telegram chat.

  Returns the total count of members in the specified chat, group,
  supergroup, or channel.

  ## Examples

      iex> GetChatMemberCount.focus(%{chat_id: -1001234567890}, %{})
      {:ok, %{chat_id: -1001234567890, member_count: 1543}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat Member Count",
    description: "Retrieves the number of members in a Telegram chat",
    url: "https://api.telegram.org/bot/getChatMemberCount",
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
  def after_focus(%{"ok" => true, "result" => count}) when is_integer(count) do
    {:ok, %{member_count: count}}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
