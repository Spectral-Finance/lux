defmodule Lux.Lenses.Telegram.Chat.GetChatAdministrators do
  @moduledoc """
  A lens for getting a list of administrators in a chat.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat Administrators",
    description: "Returns a list of administrators in a chat.",
    url: "https://api.telegram.org/bot/getChatAdministrators",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat or username of the target supergroup or channel"
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => administrators}) do
    {:ok, administrators}
  end

  def after_focus(%{"ok" => false} = error) do
    {:error, error}
  end
end
