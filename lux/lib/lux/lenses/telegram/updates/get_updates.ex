defmodule Lux.Lenses.Telegram.Updates.GetUpdates do
  @moduledoc """
  A lens for receiving incoming updates via long polling (`/getUpdates`).
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Updates",
    description: "Receives incoming updates using long polling",
    url: "https://api.telegram.org/bot/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned"
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved (1-100)"
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling"
        }
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => updates}) when is_list(updates) do
    {:ok, updates}
  end

  def after_focus(other), do: {:ok, other}
end
