defmodule Lux.Lenses.Telegram.Webhooks.GetWebhookInfo do
  @moduledoc """
  A lens for checking the current status of a webhook on Telegram Bot API.

  ## Examples

      iex> GetWebhookInfo.focus(%{})
      {:ok, %{
        url: "https://my-lux-agent.domain/webhook/telegram",
        has_custom_certificate: false,
        pending_update_count: 0
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Gets current webhook status on Telegram Bot API",
    url: "https://api.telegram.org/bot/getWebhookInfo",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @doc """
  Transforms the Telegram API response into webhook diagnostic information.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok,
     %{
       url: result["url"],
       has_custom_certificate: result["has_custom_certificate"],
       pending_update_count: result["pending_update_count"],
       last_error_date: result["last_error_date"],
       last_error_message: result["last_error_message"],
       max_connections: result["max_connections"],
       ip_address: result["ip_address"]
     }}
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
