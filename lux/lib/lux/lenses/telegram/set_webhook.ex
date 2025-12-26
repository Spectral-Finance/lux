defmodule Lux.Lenses.Telegram.SetWebhook do
  @moduledoc """
  Lens for setting up webhooks for the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.SetWebhook.focus(%{
        url: "https://example.com/webhook",
        max_connections: 40
      })
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Set Telegram Webhook",
    description: "Configures a webhook to receive incoming updates",
    url: "https://api.telegram.org/bot:token/setWebhook",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use empty string to remove webhook"
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous connections",
          minimum: 1,
          maximum: 100,
          default: 40
        },
        allowed_updates: %{
          type: :array,
          description: "List of update types to receive"
        }
      },
      required: ["url"]
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => true}), do: {:ok, %{webhook_set: true}}

  def after_focus(%{"ok" => true, "result" => result}) when is_map(result) do
    {:ok, %{webhook_set: true, details: result}}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
