defmodule Lux.Lenses.Telegram.Messaging.GetWebhookInfo do
  @moduledoc """
  A lens for getting webhook info from Telegram.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Lens,
    name: "Get Telegram Webhook Info",
    description: "Gets current webhook status from Telegram",
    url: "https://api.telegram.org/bot/:token/getWebhookInfo",
    method: :get,
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def focus(_params) do
    case Client.request(:get, "/getWebhookInfo") do
      {:ok, %{"result" => info}} ->
        {:ok, %{
          url: info["url"],
          has_custom_certificate: info["has_custom_certificate"],
          pending_update_count: info["pending_update_count"],
          last_error_date: info["last_error_date"],
          last_error_message: info["last_error_message"],
          max_connections: info["max_connections"],
          allowed_updates: info["allowed_updates"]
        }}

      {:error, {status, description}} ->
        {:error, %{status: status, description: description}}

      {:error, error} ->
        {:error, %{error: inspect(error)}}
    end
  end
end
