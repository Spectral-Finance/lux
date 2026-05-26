defmodule Lux.Lenses.Telegram.GetWebhookInfo do
  @moduledoc """
  A lens for getting current webhook status.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Returns current webhook status",
    url: "https://api.telegram.org/bot:token/getWebhookInfo",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth()

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(error) do
    {:error, error}
  end
end
