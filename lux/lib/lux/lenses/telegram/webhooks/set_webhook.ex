defmodule Lux.Lenses.Telegram.Webhooks.SetWebhook do
  @moduledoc """
  A lens for configuring webhooks on Telegram Bot API.

  ## Examples

      iex> SetWebhook.focus(%{
      ...>   url: "https://my-lux-agent.domain/webhook/telegram",
      ...>   secret_token: "sovereign_secret_123"
      ...> })
      {:ok, %{success: true, description: "Webhook was set"}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Set Telegram Webhook",
    description: "Specifies a URL and receives incoming updates via an outgoing webhook",
    url: "https://api.telegram.org/bot/setWebhook",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description:
            "HTTPS URL to send updates to. Use an empty string to remove webhook integration"
        },
        secret_token: %{
          type: :string,
          description:
            "A secret token to be sent in a header 'X-Telegram-Bot-Api-Secret-Token' in every webhook request"
        },
        max_connections: %{
          type: :integer,
          description:
            "The maximum allowed number of simultaneous HTTPS connections to the webhook for update delivery (1-100)",
          minimum: 1,
          maximum: 100
        },
        allowed_updates: %{
          type: :array,
          items: %{type: :string},
          description: "A JSON-serialized list of the update types you want your bot to receive"
        },
        drop_pending_updates: %{
          type: :boolean,
          description: "Pass True to drop all pending updates"
        }
      },
      required: ["url"]
    }

  @doc """
  Transforms the Telegram API response into a webhook confirmation.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => true, "description" => description}) do
    {:ok, %{success: true, description: description}}
  end

  def after_focus(%{"ok" => true, "result" => true}) do
    {:ok, %{success: true, description: "Webhook was set successfully"}}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(%{"description" => description}) do
    {:error, description}
  end

  def after_focus(error) do
    {:error, error}
  end
end
