defmodule Lux.Lenses.Telegram.ListUpdates do
  @moduledoc """
  A lens for retrieving incoming updates using long polling.

  ## Examples

      iex> ListUpdates.focus()
      {:ok, [%{"update_id" => 1234567, "message" => %{...}}]}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "List Telegram Updates",
    description: "Retrieves incoming updates using the getUpdates Telegram Bot API endpoint",
    url: "https://api.telegram.org/bot:token/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned. Must be greater by one than the highest among the identifiers of previously received updates."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved. Values between 1-100 are accepted. Defaults to 100.",
          minimum: 1,
          maximum: 100,
          default: 100
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling. Defaults to 0, i.e. usual short polling.",
          minimum: 0
        },
        allowed_updates: %{
          type: :array,
          description: "A JSON-serialized list of the update types you want your bot to receive. For example, specify [\"message\", \"edited_channel_post\", \"callback_query\"]",
          items: %{
            type: :string
          }
        }
      }
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => updates}) when is_list(updates) do
    {:ok, updates}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  @impl true
  def after_focus(other) do
    {:error, "Unexpected response format: #{inspect(other)}"}
  end
end
