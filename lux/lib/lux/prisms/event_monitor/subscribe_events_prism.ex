defmodule Lux.Prisms.EventMonitor.SubscribeEventsPrism do
  @moduledoc """
  Prism for creating a new smart contract event subscription.

  This prism creates a subscription to monitor events from a specified contract
  address on a given chain. It supports event filtering by name and topic,
  ABI-based decoding, and configurable polling intervals.

  ## Examples

      iex> Lux.Prisms.EventMonitor.SubscribeEventsPrism.run(%{
      ...>   address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   chain_id: 1,
      ...>   event_names: ["Transfer", "Approval"],
      ...>   from_block: 18000000,
      ...>   poll_interval_ms: 15000
      ...> })
      {:ok, %{subscription_id: "sub_abc123", status: "active"}}
  """

  use Lux.Prism,
    name: "Subscribe to Contract Events",
    description: "Creates a subscription to monitor smart contract events in real-time",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Contract address to monitor"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID (1=Ethereum, 137=Polygon, 56=BSC, etc.)"
        },
        event_names: %{
          type: :array,
          items: %{type: :string},
          description: "Event names to filter (empty = all events)"
        },
        abi: %{
          type: :array,
          description: "Contract ABI for event decoding"
        },
        from_block: %{
          type: :integer,
          description: "Block number to start monitoring from"
        },
        poll_interval_ms: %{
          type: :integer,
          description: "Polling interval in milliseconds (default: 15000)"
        },
        topics: %{
          type: :array,
          items: %{type: :string},
          description: "Topic filters for raw event matching"
        },
        metadata: %{
          type: :object,
          description: "Arbitrary metadata to attach to the subscription"
        }
      },
      required: ["address", "chain_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{
          type: :string,
          description: "Unique subscription identifier"
        },
        status: %{
          type: :string,
          description: "Subscription status"
        },
        address: %{
          type: :string,
          description: "Monitored contract address"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID"
        }
      },
      required: ["subscription_id", "status"]
    }

  alias Lux.EventMonitor

  @impl true
  def handler(input, ctx) do
    monitor = get_monitor(ctx)

    config = %{
      address: input[:address] || input["address"],
      chain_id: input[:chain_id] || input["chain_id"],
      event_names: input[:event_names] || input["event_names"] || [],
      abi: input[:abi] || input["abi"],
      from_block: input[:from_block] || input["from_block"] || :latest,
      poll_interval_ms: input[:poll_interval_ms] || input["poll_interval_ms"] || 15_000,
      topics: input[:topics] || input["topics"],
      metadata: input[:metadata] || input["metadata"] || %{}
    }

    case EventMonitor.subscribe(monitor, config) do
      {:ok, subscription_id} ->
        {:ok, %{
          subscription_id: subscription_id,
          status: "active",
          address: config.address,
          chain_id: config.chain_id
        }}

      {:error, reason} ->
        {:error, "Failed to subscribe: #{inspect(reason)}"}
    end
  end

  defp get_monitor(nil), do: Lux.EventMonitor
  defp get_monitor(%{monitor: monitor}), do: monitor
  defp get_monitor(_), do: Lux.EventMonitor
end
