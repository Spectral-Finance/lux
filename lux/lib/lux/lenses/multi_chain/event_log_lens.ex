defmodule Lux.Lenses.MultiChain.EventLogLens do
  @moduledoc """
  Lens for fetching smart contract event logs across EVM chains.

  Provides access to filtered event logs using topic-based filtering
  via the Etherscan v2 API with chain routing.

  ## Examples

      # Get Transfer events for USDT on Ethereum
      Lux.Lenses.MultiChain.EventLogLens.focus(%{
        address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        chainid: 1,
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        fromBlock: 18000000,
        toBlock: 18000100
      })
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.EventLogLens",
    description: "Fetches smart contract event logs across EVM chains",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Chain ID (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        address: %{
          type: :string,
          description: "Contract address to filter logs",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        topic0: %{
          type: :string,
          description: "Topic 0 (event signature hash)"
        },
        topic1: %{
          type: :string,
          description: "Topic 1 filter"
        },
        topic2: %{
          type: :string,
          description: "Topic 2 filter"
        },
        topic3: %{
          type: :string,
          description: "Topic 3 filter"
        },
        topic0_1_opr: %{
          type: :string,
          description: "Operator between topic0 and topic1 (and/or)",
          enum: ["and", "or"]
        },
        fromBlock: %{
          type: :integer,
          description: "Starting block number",
          default: 0
        },
        toBlock: %{
          type: :integer,
          description: "Ending block number"
        },
        page: %{
          type: :integer,
          description: "Page number",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of results per page",
          default: 1000
        }
      },
      required: ["address"]
    }

  def before_focus(params) do
    params
    |> Map.put(:module, "logs")
    |> Map.put(:action, "getLogs")
  end

  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
