defmodule Lux.Prisms.EthWebhookNotifier do
  @moduledoc """
  Prism for handling webhook notifications.

  ## Examples

  # Send a webhook notification
  Lux.Prisms.EthWebhookNotifier.notify(%{
    url: "https://example.com/webhook",
    payload: %{
      message: "Transaction completed"
    }
  })
  """

  use Lux.Prism,
    name: "EthWebhookNotifier",
    description: "Sends a webhook notification with the provided payload",
    url: "",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :none
    },
    schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "Webhook URL to send the notification"
        },
        payload: %{
          type: :object,
          description: "Payload data to be sent with the webhook"
        }
      },
      required: [:url, :payload]
    }
  end