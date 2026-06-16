defmodule Lux.Lenses.Telegram.GetWebhookInfo do
  @moduledoc """
  A lens for retrieving current webhook status.

  ## Examples

      iex> GetWebhookInfo.focus()
      {:ok, %{"url" => "https://example.com/webhook", "has_custom_certificate" => false, ...}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Retrieves current webhook status using the getWebhookInfo Telegram Bot API endpoint",
    url: "https://api.telegram.org/bot:token/getWebhookInfo",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => webhook_info}) when is_map(webhook_info) do
    {:ok, webhook_info}
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
