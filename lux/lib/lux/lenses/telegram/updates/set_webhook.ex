defmodule Lux.Lenses.Telegram.Updates.SetWebhook do
  @moduledoc """
  A lens to specify a URL and receive incoming updates via an outgoing webhook.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Set Webhook",
    description: "Specifies a URL to receive incoming updates via webhook.",
    url: "https://api.telegram.org/bot<token>/setWebhook",
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTPS URL to send updates to. Use an empty string to remove webhook integration"
        },
        secret_token: %{
          type: :string,
          description: "A secret token to be sent in a header X-Telegram-Bot-Api-Secret-Token in every webhook request, 1-256 characters."
        }
      },
      required: ["url"]
    }

  @doc """
  Transforms the Telegram API response.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end
  
  def after_focus(other), do: {:error, other}
end
