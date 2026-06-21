defmodule Lux.Lenses.Telegram.Chat.GetChat do
  @moduledoc """
  A lens for getting up to date information about the chat.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat",
    description: "Returns basic information about the chat.",
    url: "https://api.telegram.org/bot/getChat",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "Unique identifier for the target chat or username of the target supergroup or channel (in the format @channelusername)"
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => chat}) do
    {:ok, chat}
  end

  def after_focus(%{"ok" => false} = error) do
    {:error, error}
  end
end
