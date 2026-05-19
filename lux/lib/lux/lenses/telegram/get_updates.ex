defmodule Lux.Lenses.Telegram.GetUpdates do
  @moduledoc """
  A lens for getting updates from Telegram using long polling.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Updates",
    description: "Returns an array of Update objects",
    url: "https://api.telegram.org/bot:token/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{type: :integer, description: "Identifier of the first update to be returned"},
        limit: %{type: :integer, description: "Limits the number of updates to be retrieved", minimum: 1, maximum: 100, default: 100},
        timeout: %{type: :integer, description: "Timeout in seconds for long polling", default: 0},
        allowed_updates: %{type: :array, items: %{type: :string}, description: "A JSON-serialized list of the update types you want your bot to receive"}
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(error) do
    {:error, error}
  end
end
