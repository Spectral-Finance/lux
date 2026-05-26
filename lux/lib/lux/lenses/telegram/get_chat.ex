defmodule Lux.Lenses.Telegram.GetChat do
  @moduledoc """
  A lens for getting information about a chat.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Chat Info",
    description: "Returns information about a chat",
    url: "https://api.telegram.org/bot:token/getChat",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Unique identifier for the target chat or username of the target supergroup or channel"}
      },
      required: ["chat_id"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(error) do
    {:error, error}
  end
end
