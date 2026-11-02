defmodule Lux.Lenses.Telegram.Webhooks.GetWebhookInfo do
  @moduledoc """
  A lens for retrieving current webhook status from Telegram Bot API.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Returns the current webhook status",
    url: "https://api.telegram.org/bot/getWebhookInfo",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => info}) do
    {:ok, info}
  end

  def after_focus(other), do: {:ok, other}
end
