defmodule Lux.Lenses.Telegram.Bot.SetWebhook do
  @moduledoc """
  A lens for setting a webhook URL via the Telegram Bot API.

  This lens configures a webhook so Telegram sends updates to your specified URL
  instead of requiring long polling via getUpdates.

  ## Important Notes

  - The URL must use HTTPS (except for testing with self-signed certificates)
  - Ports 443, 80, 88, and 8443 are supported
  - Setting a webhook automatically disables getUpdates
  - Use `DeleteWebhook` to switch back to long polling

  ## Examples

      iex> SetWebhook.focus(%{
      ...>   url: "https://example.com/webhook/telegram"
      ...> })
      {:ok, %{set: true, description: "Webhook was set"}}

      iex> SetWebhook.focus(%{
      ...>   url: "https://example.com/webhook/telegram",
      ...>   max_connections: 40,
      ...>   allowed_updates: ["message", "callback_query"],
      ...>   secret_token: "my-secret-token"
      ...> })
      {:ok, %{set: true, description: "Webhook was set"}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Set Telegram Webhook",
    description: "Sets a webhook URL for receiving updates from Telegram",
    url: Telegram.api_url("setWebhook"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use an empty string to remove the webhook."
        },
        certificate: %{
          type: :string,
          description: "Upload your public key certificate (PEM encoded) so that the root certificate in use can be checked"
        },
        ip_address: %{
          type: :string,
          description: "Fixed IP address to be used to send webhook requests instead of the IP resolved through DNS"
        },
        max_connections: %{
          type: :integer,
          description: "Maximum allowed number of simultaneous HTTPS connections to the webhook (1-100, default 40)",
          minimum: 1,
          maximum: 100,
          default: 40
        },
        allowed_updates: %{
          type: :array,
          description: "List of update types to receive",
          items: %{type: :string}
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        },
        secret_token: %{
          type: :string,
          description: "A secret token (1-256 characters) to be sent in the header X-Telegram-Bot-Api-Secret-Token in every webhook request"
        }
      },
      required: ["url"]
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true, "description" => description}) do
    {:ok, %{set: true, description: description}}
  end

  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{set: true, description: "Webhook was set"}}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
