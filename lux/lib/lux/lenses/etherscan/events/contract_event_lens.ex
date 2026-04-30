defmodule Lux.Lenses.Etherscan.Events.ContractEventLens do
  @moduledoc """
  Lens for fetching and decoding contract event logs from the Etherscan API.

  Retrieves structured event data with decoded parameters for any contract
  on supported EVM chains. This lens uses the Etherscan `logs` module
  with `getLogs` action to fetch event logs filtered by contract address,
  event signature (topic0), and block range.

  ## Event Signatures (topic0)

  Common event signatures:

  | Event                                  | topic0                                                                 |
  |----------------------------------------|------------------------------------------------------------------------|
  | Transfer (ERC-20/ERC-721)              | 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef     |
  | Approval (ERC-20)                      | 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925     |
  | Mint (ERC-721)                         | 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb     |
  | Swap (Uniswap V2)                      | 0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822     |
  | Swap (Uniswap V3)                      | 0xc42079f94a6350d7e6235f29174924f91065fbc2da3237a9a9b3f4a31aace1a1     |

  ## Examples

  ```elixir
  # Get events for a specific contract
  Lux.Lenses.Etherscan.Events.ContractEventLens.focus(%{
    contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",  # UNI token
    topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    from_block: 18_000_000,
    to_block: 18_001_000
  })

  # Get events on Polygon
  Lux.Lenses.Etherscan.Events.ContractEventLens.focus(%{
    contract_address: "0x2791Bca1f2de4661ED88A30C99A7a1Aaf9c0b0d4",  # Chainlink on Polygon
    topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    from_block: 45_000_000,
    to_block: 45_001_000,
    chainid: 137
  })

  # Get events with topic filtering
  Lux.Lenses.Etherscan.Events.ContractEventLens.focus(%{
    contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
    topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    topic1: "0x000000000000000000000000c5102fe9359fd9a28f877a67e36b0f050d81a3cc",
    from_block: 18_000_000,
    to_block: 18_001_000,
    page: 1,
    offset: 100
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.Events.ContractEvent",
    description: "Fetches contract event logs with decoded parameters from the Etherscan API",
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
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, 42161=Arbitrum, 10=Optimism)",
          default: 1
        },
        contract_address: %{
          type: :string,
          description: "Contract address to fetch events from",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        topic0: %{
          type: :string,
          description: "Event signature hash (keccak256 of event signature) to filter by"
        },
        topic1: %{
          type: :string,
          description: "First indexed parameter to filter by (second topic position)"
        },
        topic2: %{
          type: :string,
          description: "Second indexed parameter to filter by (third topic position)"
        },
        topic3: %{
          type: :string,
          description: "Third indexed parameter to filter by (fourth topic position)"
        },
        topic0_1_opr: %{
          type: :string,
          description: "Logical operator between topic0 and topic1",
          enum: ["and", "or"]
        },
        from_block: %{
          type: :integer,
          description: "Starting block number (inclusive)"
        },
        to_block: %{
          type: :integer,
          description: "Ending block number (inclusive)"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of events to return per page (max 1000)",
          default: 100
        }
      },
      required: ["contract_address", "from_block", "to_block"]
    }

  @doc """
  Prepares parameters before making the API request.

  Maps the schema fields to Etherscan API parameter names.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "logs")
    |> Map.put(:action, "getLogs")
    |> Map.update(:contract_address, nil, fn addr ->
      if addr, do: addr, else: nil
    end)
    |> maybe_put(:from_block, :fromBlock)
    |> maybe_put(:to_block, :toBlock)
    |> maybe_put(:topic0, :topic0)
    |> maybe_put(:topic1, :topic1)
    |> maybe_put(:topic2, :topic2)
    |> maybe_put(:topic3, :topic3)
    |> maybe_put(:topic0_1_opr, :topic0_1_opr)
  end

  defp maybe_put(params, key, new_key) do
    case Map.get(params, key) do
      nil -> params
      value -> Map.put(params, new_key, value)
    end
  end

  @doc """
  Transforms the API response into a structured format with decoded event data.

  ## Examples

      iex> after_focus(%{"status" => "1", "result" => [%{"address" => "0x...", "topics" => [...], ...}]})
      {:ok, %{events: [%{address: "0x...", topics: [...], ...}]}}
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        events = Enum.map(result, &transform_event/1)

        {:ok, %{
          events: events,
          count: length(events)
        }}

      other ->
        other
    end
  end

  defp transform_event(log) do
    %{
      address: Map.get(log, "address", ""),
      topics: Map.get(log, "topics", []),
      data: Map.get(log, "data", ""),
      block_number: Map.get(log, "blockNumber", ""),
      timestamp: Map.get(log, "timeStamp", ""),
      gas_price: Map.get(log, "gasPrice", ""),
      gas_used: Map.get(log, "gasUsed", ""),
      log_index: Map.get(log, "logIndex", ""),
      transaction_hash: Map.get(log, "transactionHash", ""),
      transaction_index: Map.get(log, "transactionIndex", "")
    }
  end
end
