defmodule Lux.Prisms.Web3.MonitorEvents do
  @moduledoc """
  A prism to manage live subscription and processing of EVM smart contract events.
  """
  use Lux.Prism,
    name: "Web3 Smart Contract Event Monitor",
    description: "Sets up a live WebSocket subscription to monitor EVM smart contract events.",
    input_schema: %{
      type: :object,
      properties: %{
        url: %{
          type: :string,
          description: "WebSocket RPC URL (e.g. wss://mainnet.infura.io/ws/v3/...)"
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
        webhook_url: %{
          type: :string,
          description: "Optional webhook URL to alert on new events."
        }
      },
      required: ["url"]
    }

  alias Lux.Integrations.Web3.EventMonitor

  def handler(%{url: url} = params, _context) do
    opts = [
      url: url,
      address: Map.get(params, :address),
      topics: Map.get(params, :topics, []),
      webhook_url: Map.get(params, :webhook_url)
    ]
    
    # Prune nil options
    opts = Enum.reject(opts, fn {_k, v} -> is_nil(v) end)
    
    case EventMonitor.start_monitor(opts) do
      {:ok, pid} -> 
        {:ok, %{status: "monitoring_started", pid: inspect(pid)}}
      {:error, reason} -> 
        {:error, "Failed to start monitor: #{inspect(reason)}"}
    end
  end
end
