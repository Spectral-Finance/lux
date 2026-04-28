defmodule Lux.Integrations.SmartContractEvents.Webhook do
  @moduledoc "Webhook notification system for contract events"

  @doc "Send webhook notification for an event"
  def notify(nil, _event), do: :ok
  def notify(webhook_url, event) when is_binary(webhook_url) do
    payload = Jason.encode!(%{
      event: "contract_event",
      data: event,
      timestamp: DateTime.utc_now()
    })

    HTTPoison.post(webhook_url, payload, [{"Content-Type", "application/json"}])
    :ok
  end
end
