defmodule Lux.Lenses.Telegram.Bot.GetWebhookInfo do
  @moduledoc """
  A lens for retrieving current webhook configuration of the Telegram bot.

  Returns information about the bot's webhook settings including the URL,
  pending update count, and any recent errors.

  ## Examples

      iex> GetWebhookInfo.focus(%{}, %{})
      {:ok, %{
        url: "https://example.com/webhook",
        has_custom_certificate: false,
        pending_update_count: 0,
        last_error_date: nil,
        last_error_message: nil,
        max_connections: 40,
        allowed_updates: ["message", "callback_query"]
      }}

      # When no webhook is set
      iex> GetWebhookInfo.focus(%{}, %{})
      {:ok, %{url: "", has_custom_certificate: false, pending_update_count: 0}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Retrieves current webhook configuration and status for the Telegram bot",
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
    {:ok, %{
      url: info["url"],
      has_custom_certificate: info["has_custom_certificate"],
      pending_update_count: info["pending_update_count"],
      ip_address: info["ip_address"],
      last_error_date: info["last_error_date"],
      last_error_message: info["last_error_message"],
      last_synchronization_error_date: info["last_synchronization_error_date"],
      max_connections: info["max_connections"],
      allowed_updates: info["allowed_updates"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
