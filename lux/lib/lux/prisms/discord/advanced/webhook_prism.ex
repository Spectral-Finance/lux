defmodule Lux.Prisms.Discord.Advanced.WebhookPrism do
  @moduledoc """
  A prism that manages Discord webhook creation, custom payload formatting, and event dispatch.
  """

  use Lux.Prism,
    name: "Discord Webhook Prism",
    description: "Creates, configures, and triggers Discord webhooks with event metadata",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create_webhook", "send_message", "trigger_event"],
          default: "send_message"
        },
        channel_id: %{type: :string},
        name: %{type: :string},
        webhook_url: %{type: :string},
        content: %{type: :string},
        event_name: %{type: :string},
        event_data: %{type: :object}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: [:object, :null]},
        status: %{type: :string}
      },
      required: ["action", "status"]
    }

  alias Lux.Discord.Webhook

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "send_message")

    case action do
      "create_webhook" ->
        channel_id = Map.get(inputs, "channel_id") || Map.get(inputs, :channel_id, "default_ch")
        name = Map.get(inputs, "name") || Map.get(inputs, :name, "Lux Webhook")
        {:ok, wh} = Webhook.create_webhook(channel_id, name)
        {:ok, %{action: "create_webhook", result: wh, status: "created"}}

      "send_message" ->
        url = Map.get(inputs, "webhook_url") || Map.get(inputs, :webhook_url, "https://discord.com/api/webhooks/mock/token")
        content = Map.get(inputs, "content") || Map.get(inputs, :content, "Notification from Lux Agent")
        {:ok, res} = Webhook.send_webhook_message(url, content)
        {:ok, %{action: "send_message", result: res, status: "delivered"}}

      "trigger_event" ->
        url = Map.get(inputs, "webhook_url") || Map.get(inputs, :webhook_url, "https://discord.com/api/webhooks/mock/token")
        ev_name = Map.get(inputs, "event_name") || Map.get(inputs, :event_name, "AGENT_TASK_COMPLETED")
        ev_data = Map.get(inputs, "event_data") || Map.get(inputs, :event_data, %{status: "success"})
        {:ok, res} = Webhook.trigger_event(ev_name, ev_data, url)
        {:ok, %{action: "trigger_event", result: res, status: "triggered"}}
    end
  end
end
