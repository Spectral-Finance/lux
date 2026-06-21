defmodule Lux.Lenses.Telegram.Messaging.GetUpdates do
  @moduledoc """
  A lens for receiving incoming updates using long polling.
  This lens provides a simple interface for fetching updates.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Updates",
    description: "Use this method to receive incoming updates using long polling.",
    url: "https://api.telegram.org/bot/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved. Values between 1-100 are accepted. Defaults to 100.",
          minimum: 1,
          maximum: 100
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling."
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "A JSON-serialized list of the update types you want your bot to receive."
        }
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => updates}) do
    {:ok, updates}
  end

  def after_focus(%{"ok" => false} = error) do
    {:error, error}
  end
end
