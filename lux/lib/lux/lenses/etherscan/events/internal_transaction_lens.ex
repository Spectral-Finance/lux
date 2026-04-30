defmodule Lux.Lenses.Etherscan.Events.InternalTransactionLens do
  @moduledoc """
  Lens for monitoring internal (internal) transactions from the Etherscan API.

  Retrieves internal transaction data for a given address, including contract
  creations, self-destructs, and value transfers between contracts. Internal
  transactions are transactions initiated by a contract rather than an
  externally-owned account (EOA).

  This lens uses the Etherscan `account` module with `txlistinternal` action.

  ## Examples

  ```elixir
  # Get internal transactions for an address
  Lux.Lenses.Etherscan.Events.InternalTransactionLens.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
    page: 1,
    offset: 50
  })

  # Get internal transactions within a block range
  Lux.Lenses.Etherscan.Events.InternalTransactionLens.focus(%{
    address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
    start_block: 18_000_000,
    end_block: 18_001_000,
    page: 1,
    offset: 100
  })

  # Get internal transactions on Arbitrum
  Lux.Lenses.Etherscan.Events.InternalTransactionLens.focus(%{
    address: "0x...",
    chainid: 42161,
    start_block: 10_000_000,
    end_block: 10_001_000,
    page: 1,
    offset: 50
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.Events.InternalTransaction",
    description: "Monitors internal transactions (contract-to-contract) for a given address",
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
        address: %{
          type: :string,
          description: "Address to query internal transactions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        start_block: %{
          type: :integer,
          description: "Starting block number (inclusive)",
          default: 0
        },
        end_block: %{
          type: :integer,
          description: "Ending block number (inclusive)",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transactions to return per page",
          default: 100
        },
        sort: %{
          type: :string,
          description: "Sort order for results",
          enum: ["asc", "desc"],
          default: "desc"
        }
      },
      required: ["address"]
    }

  @doc """
  Prepares parameters before making the API request.

  Maps the schema fields to Etherscan API parameter names.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "txlistinternal")
    |> maybe_put(:start_block, :startblock)
    |> maybe_put(:end_block, :endblock)
    |> Map.put_new(:sort, "desc")
  end

  defp maybe_put(params, key, new_key) do
    case Map.get(params, key) do
      nil -> params
      value -> Map.put(params, new_key, value)
    end
  end

  @doc """
  Transforms the API response into a structured format with internal transaction details.

  ## Examples

      iex> after_focus(%{"status" => "1", "result" => [%{"hash" => "0x...", "from" => "0x...", ...}]})
      {:ok, %{internal_transactions: [%{hash: "0x...", from: "0x...", ...}]}}
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        transactions = Enum.map(result, &transform_transaction/1)

        {:ok, %{
          internal_transactions: transactions,
          count: length(transactions)
        }}

      other ->
        other
    end
  end

  defp transform_transaction(tx) do
    %{
      hash: Map.get(tx, "hash", ""),
      from: Map.get(tx, "from", ""),
      to: Map.get(tx, "to", ""),
      value: Map.get(tx, "value", ""),
      contract_address: Map.get(tx, "contractAddress", ""),
      input: Map.get(tx, "input", ""),
      type: Map.get(tx, "type", ""),
      gas: Map.get(tx, "gas", ""),
      gas_used: Map.get(tx, "gasUsed", ""),
      trace_id: Map.get(tx, "traceId", ""),
      block_number: Map.get(tx, "blockNumber", ""),
      timestamp: Map.get(tx, "timeStamp", ""),
      error: Map.get(tx, "error", ""),
      is_error: Map.get(tx, "isError", "")
    }
  end
end
