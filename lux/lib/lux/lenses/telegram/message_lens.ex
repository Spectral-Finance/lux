defmodule Lux.Lenses.Telegram.MessageLens do
  @moduledoc """
  Lens for polling and inspecting Telegram updates and messages via `/getUpdates`.
  """

  use Lux.Lens,
    name: "Telegram Message Lens",
    description: "Fetches and focuses on incoming Telegram updates, messages, and channel posts.",
    url: "https://api.telegram.org/bot/getUpdates",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Telegram.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved (1-100).",
          default: 100
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling.",
          default: 30
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "List of the update types you want your bot to receive."
        }
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => updates}) when is_list(updates) do
    {:ok, %{updates: updates, count: length(updates)}}
  end

  def after_focus(%{"ok" => false, "description" => desc}) do
    {:error, "Telegram API error: #{desc}"}
  end

  def after_focus(other), do: {:ok, other}
end
