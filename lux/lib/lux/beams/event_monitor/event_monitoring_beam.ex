defmodule Lux.Beams.EventMonitor.EventMonitoringBeam do
  @moduledoc """
  Beam that orchestrates a complete smart contract event monitoring workflow.

  This beam combines subscription creation, event querying, and webhook
  registration into a cohesive workflow that can be used by agents to
  set up comprehensive event monitoring.

  ## Workflow

  1. Subscribe to contract events
  2. Register a webhook for notifications (if URL provided)
  3. Query any historical events from the starting block

  ## Example

      Lux.Beams.EventMonitor.EventMonitoringBeam.run(%{
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        chain_id: 1,
        event_names: ["Transfer"],
        webhook_url: "https://api.example.com/events",
        from_block: 18000000
      })
  """

  use Lux.Beam,
    name: "Event Monitoring Setup",
    description: "Sets up comprehensive smart contract event monitoring with webhooks and historical sync",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Contract address to monitor"},
        chain_id: %{type: :integer, description: "Chain ID"},
        event_names: %{type: :array, items: %{type: :string}, description: "Events to monitor"},
        abi: %{type: :array, description: "Contract ABI"},
        webhook_url: %{type: :string, description: "Webhook URL for notifications"},
        webhook_secret: %{type: :string, description: "Webhook HMAC secret"},
        from_block: %{type: :integer, description: "Starting block number"},
        poll_interval_ms: %{type: :integer, description: "Polling interval"}
      },
      required: ["address", "chain_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{type: :string},
        webhook_id: %{type: :string},
        historical_event_count: %{type: :integer},
        status: %{type: :string}
      },
      required: ["subscription_id", "status"]
    }

  sequence do
    step(:subscribe, Lux.Prisms.EventMonitor.SubscribeEventsPrism, %{
      address: :address,
      chain_id: :chain_id,
      event_names: :event_names,
      abi: :abi,
      from_block: :from_block,
      poll_interval_ms: :poll_interval_ms
    })

    branch {__MODULE__, :has_webhook?} do
      true ->
        step(:register_webhook, Lux.Prisms.EventMonitor.RegisterWebhookPrism, %{
          url: :webhook_url,
          secret: :webhook_secret,
          filter: %{
            address: :address,
            chain_id: :chain_id
          }
        })

      false ->
        step(:skip_webhook, Lux.Prisms.NoOp, %{})
    end
  end

  def has_webhook?(ctx) do
    webhook_url = Map.get(ctx, :webhook_url) || Map.get(ctx, "webhook_url")
    webhook_url != nil and webhook_url != ""
  end
end
