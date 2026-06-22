defmodule Lux.Prisms.Web3.SyncHistoricalEvents do
  @moduledoc """
  A prism to fetch historical EVM smart contract events using eth_getLogs.
  """
  use Lux.Prism,
    name: "Web3 Historical Event Sync",
    description: "Fetches historical events and stores them in the event monitor storage.",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "HTTP RPC URL (e.g. https://mainnet.infura.io/v3/...)"
        },
        address: %{
          type: :string,
          description: "The contract address to monitor."
        },
        topics: %{
          type: :array,
          items: %{type: :string},
          description: "List of topic strings to filter logs."
        },
        from_block: %{
          type: :string,
          description: "Hex block number or tag (e.g. 'earliest')"
        },
        to_block: %{
          type: :string,
          description: "Hex block number or tag (e.g. 'latest')"
        }
      },
      required: ["url"]
    }

  alias Lux.Integrations.Web3.EventMonitor

  def handler(%{url: url} = params, _context) do
    opts = [
      url: url,
      address: Map.get(params, :address),
      topics: Map.get(params, :topics),
      from_block: Map.get(params, :from_block, "earliest"),
      to_block: Map.get(params, :to_block, "latest")
    ]
    
    # Prune nil options
    opts = Enum.reject(opts, fn {_k, v} -> is_nil(v) end)
    
    case EventMonitor.sync_historical(opts) do
      {:ok, count} -> 
        {:ok, %{status: "synced", event_count: count}}
      {:error, reason} -> 
        {:error, "Failed to sync historical events: #{inspect(reason)}"}
    end
  end
end
