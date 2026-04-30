defmodule Lux.Lenses.Etherscan.Events.NewContractsLens do
  @moduledoc """
  Lens for monitoring new contract deployments from the Etherscan API.

  Retrieves information about newly deployed smart contracts within a specified
  block range. This lens uses the Etherscan `contract` module with
  `getcontractcreation` action to identify contract addresses and their creators.

  ## Use Cases

  - Track new DeFi protocol deployments
  - Monitor NFT collection launches
  - Identify potential rug pulls or honeypots
  - Research new token launches
  - Track developer activity

  ## Examples

  ```elixir
  # Get new contracts deployed in a block range
  Lux.Lenses.Etherscan.Events.NewContractsLens.focus(%{
    block_start: 18_000_000,
    block_end: 18_001_000,
    page: 1
  })

  # Get new contracts on BSC
  Lux.Lenses.Etherscan.Events.NewContractsLens.focus(%{
    block_start: 30_000_000,
    block_end: 30_001_000,
    chainid: 56,
    page: 1,
    offset: 100
  })

  # Get new contracts on Arbitrum
  Lux.Lenses.Etherscan.Events.NewContractsLens.focus(%{
    block_start: 10_000_000,
    block_end: 10_001_000,
    chainid: 42161,
    page: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.Events.NewContracts",
    description: "Monitors newly deployed smart contracts and their creator addresses",
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
        block_start: %{
          type: :integer,
          description: "Starting block number to search for new contracts"
        },
        block_end: %{
          type: :integer,
          description: "Ending block number to search for new contracts"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of contracts to return per page",
          default: 100
        },
        sort: %{
          type: :string,
          description: "Sort order for results",
          enum: ["asc", "desc"],
          default: "desc"
        }
      },
      required: ["block_start", "block_end"]
    }

  @doc """
  Prepares parameters before making the API request.

  Maps the schema fields to Etherscan API parameter names.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "contract")
    |> Map.put(:action, "getcontractcreation")
    |> maybe_put(:block_start, :startblock)
    |> maybe_put(:block_end, :endblock)
    |> Map.put_new(:sort, "desc")
  end

  defp maybe_put(params, key, new_key) do
    case Map.get(params, key) do
      nil -> params
      value -> Map.put(params, new_key, value)
    end
  end

  @doc """
  Transforms the API response into a structured format with contract deployment details.

  ## Examples

      iex> after_focus(%{"status" => "1", "result" => [%{"contractAddress" => "0x...", "contractCreator" => "0x...", ...}]})
      {:ok, %{contracts: [%{contract_address: "0x...", creator: "0x...", ...}]}}
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        contracts = Enum.map(result, &transform_contract/1)

        {:ok, %{
          contracts: contracts,
          count: length(contracts)
        }}

      other ->
        other
    end
  end

  defp transform_contract(contract) do
    %{
      contract_address: Map.get(contract, "contractAddress", ""),
      contract_creator: Map.get(contract, "contractCreator", ""),
      tx_hash: Map.get(contract, "txHash", ""),
      block_number: Map.get(contract, "blockNumber", ""),
      method_id: Map.get(contract, "methodId", ""),
      create2_key: Map.get(contract, "create2Key", "")
    }
  end
end
