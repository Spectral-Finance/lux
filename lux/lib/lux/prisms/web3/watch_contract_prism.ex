defmodule Lux.Prisms.Web3.WatchContractPrism do
  @moduledoc """
  A Lux Prism to start watching a smart contract for events.

  Creates an EventMonitor subscription for the specified contract and event
  signatures, enabling real-time monitoring and historical event syncing.

  ## Actions

    * `"subscribe"` – Create a new event subscription (default)
    * `"unsubscribe"` – Remove an existing subscription
    * `"status"` – Check monitor status and subscription details

  ## Examples

      # Start watching USDT Transfer events
      WatchContractPrism.run(%{
        contract_address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        event_signatures: ["Transfer(address,address,uint256)"],
        chain_id: 1,
        webhook_url: "https://example.com/hooks/events"
      })
  """

  use Lux.Prism,
    name: "Web3 Watch Contract",
    description: "Starts or manages smart contract event monitoring subscriptions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: subscribe, unsubscribe, or status (default: subscribe)"
        },
        contract_address: %{
          type: :string,
          description: "The contract address to watch for events"
        },
        event_signatures: %{
          type: :array,
          items: %{type: :string},
          description: "List of event signatures (e.g. [\"Transfer(address,address,uint256)\"])"
        },
        chain_id: %{
          type: :integer,
          description: "EVM chain ID (default: 1)"
        },
        subscription_id: %{
          type: :string,
          description: "Custom subscription ID (auto-generated if omitted)"
        },
        webhook_url: %{
          type: :string,
          description: "URL to POST event notifications to"
        },
        from_block: %{
          type: :string,
          description: "Block to start monitoring from (default: latest)"
        },
        sync_from_block: %{
          type: :integer,
          description: "If set, sync historical events from this block number"
        },
        sync_to_block: %{
          type: :integer,
          description: "End block for historical sync (default: latest block)"
        }
      },
      required: ["contract_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{
          type: :string,
          description: "The subscription ID for this watch"
        },
        contract_address: %{
          type: :string,
          description: "The contract address being watched"
        },
        event_signatures: %{
          type: :array,
          items: %{type: :string},
          description: "Event signatures being monitored"
        },
        chain_id: %{
          type: :integer,
          description: "The EVM chain ID"
        },
        status: %{
          type: :string,
          description: "Current status of the subscription"
        },
        historical_events_count: %{
          type: :integer,
          description: "Number of historical events synced (if applicable)"
        }
      },
      required: ["subscription_id", "status"]
    }

  alias Lux.Web3.EventMonitor

  @impl true
  def handler(input, _ctx) do
    action = Map.get(input, :action, "subscribe") |> to_string()

    case action do
      "subscribe" -> handle_subscribe(input)
      "unsubscribe" -> handle_unsubscribe(input)
      "status" -> handle_status()
      other -> {:error, "Unknown action: #{other}. Use subscribe, unsubscribe, or status."}
    end
  end

  defp handle_subscribe(input) do
    address = input.contract_address
    chain_id = Map.get(input, :chain_id, 1)
    event_sigs = Map.get(input, :event_signatures, [])
    sub_id = Map.get(input, :subscription_id, generate_subscription_id(address))
    webhook_url = Map.get(input, :webhook_url)
    from_block = Map.get(input, :from_block, "latest")

    subscription = %{
      id: sub_id,
      contract_address: address,
      event_signatures: event_sigs,
      chain_id: chain_id,
      webhook_url: webhook_url,
      from_block: from_block
    }

    case EventMonitor.subscribe(subscription) do
      :ok ->
        result = %{
          subscription_id: sub_id,
          contract_address: address,
          event_signatures: event_sigs,
          chain_id: chain_id,
          status: "active"
        }

        # Optionally sync historical events
        result = maybe_sync_historical(input, sub_id, result)

        {:ok, result}

      {:error, reason} ->
        {:error, "Failed to subscribe: #{inspect(reason)}"}
    end
  end

  defp handle_unsubscribe(input) do
    sub_id = Map.get(input, :subscription_id)

    if sub_id do
      EventMonitor.unsubscribe(sub_id)

      {:ok,
       %{
         subscription_id: sub_id,
         status: "unsubscribed"
       }}
    else
      {:error, "subscription_id is required for unsubscribe action"}
    end
  end

  defp handle_status do
    status = EventMonitor.status()

    {:ok,
     %{
       subscription_id: "monitor",
       status: "active",
       monitor: status
     }}
  end

  defp maybe_sync_historical(input, sub_id, result) do
    case Map.get(input, :sync_from_block) do
      nil ->
        result

      from_block ->
        to_block = Map.get(input, :sync_to_block, get_latest_block_number())

        case EventMonitor.sync_historical(sub_id, from_block, to_block) do
          {:ok, events} ->
            Map.put(result, :historical_events_count, length(events))

          {:error, reason} ->
            Map.merge(result, %{
              historical_events_count: 0,
              sync_error: inspect(reason)
            })
        end
    end
  end

  defp generate_subscription_id(address) do
    short_addr = String.slice(address, 0, 10)
    timestamp = System.system_time(:second)
    "watch-#{short_addr}-#{timestamp}"
  end

  defp get_latest_block_number do
    case Ethereumex.HttpClient.eth_block_number() do
      {:ok, "0x" <> hex} -> String.to_integer(hex, 16)
      _ -> 0
    end
  end
end
