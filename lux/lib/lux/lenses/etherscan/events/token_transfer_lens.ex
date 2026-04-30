defmodule Lux.Lenses.Etherscan.Events.TokenTransferLens do
  @moduledoc """
  Lens for tracking ERC-20 token transfer events from the Etherscan API.

  Retrieves token transfer events (Transfer events) for a specific contract
  or wallet address. This lens uses the Etherscan `account` module with
  `tokentx` action to fetch ERC-20 transfer events with amounts, timestamps,
  and sender/receiver information.

  ## Examples

  ```elixir
  # Get token transfers for a contract
  Lux.Lenses.Etherscan.Events.TokenTransferLens.focus(%{
    contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",  # UNI token
    page: 1,
    offset: 50
  })

  # Get transfers for a specific wallet
  Lux.Lenses.Etherscan.Events.TokenTransferLens.focus(%{
    contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
    wallet_address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
    page: 1,
    offset: 20
  })

  # Get transfers on Polygon
  Lux.Lenses.Etherscan.Events.TokenTransferLens.focus(%{
    contract_address: "0x2791Bca1f2de4661ED88A30C99A7a1Aaf9c0b0d4",
    chainid: 137,
    page: 1,
    offset: 100
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.Events.TokenTransfer",
    description: "Tracks ERC-20 token transfer events with amounts and timestamps",
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
          description: "Token contract address to query transfers for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        wallet_address: %{
          type: :string,
          description: "Optional wallet address to filter transfers by sender/receiver"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results (starts at 1)",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transfers to return per page (max 10000)",
          default: 100
        },
        sort: %{
          type: :string,
          description: "Sort order for results",
          enum: ["asc", "desc"],
          default: "desc"
        }
      },
      required: ["contract_address"]
    }

  @doc """
  Prepares parameters before making the API request.

  Maps the schema fields to Etherscan API parameter names.
  """
  def before_focus(params) do
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokentx")
    |> Map.update(:contract_address, nil, fn addr ->
      if addr, do: addr, else: nil
    end)
    |> maybe_put(:wallet_address, :address)
    |> Map.put_new(:sort, "desc")
  end

  defp maybe_put(params, key, new_key) do
    case Map.get(params, key) do
      nil -> params
      value -> Map.put(params, new_key, value)
    end
  end

  @doc """
  Transforms the API response into a structured format with transfer details.

  ## Examples

      iex> after_focus(%{"status" => "1", "result" => [%{"hash" => "0x...", "from" => "0x...", ...}]})
      {:ok, %{transfers: [%{hash: "0x...", from: "0x...", ...}]}}
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        transfers = Enum.map(result, &transform_transfer/1)

        {:ok, %{
          transfers: transfers,
          count: length(transfers)
        }}

      other ->
        other
    end
  end

  defp transform_transfer(tx) do
    %{
      hash: Map.get(tx, "hash", ""),
      from: Map.get(tx, "from", ""),
      to: Map.get(tx, "to", ""),
      value: Map.get(tx, "value", ""),
      contract_address: Map.get(tx, "contractAddress", ""),
      token_name: Map.get(tx, "tokenName", ""),
      token_symbol: Map.get(tx, "tokenSymbol", ""),
      token_decimals: Map.get(tx, "tokenDecimal", ""),
      block_number: Map.get(tx, "blockNumber", ""),
      timestamp: Map.get(tx, "timeStamp", ""),
      gas: Map.get(tx, "gas", ""),
      gas_price: Map.get(tx, "gasPrice", ""),
      gas_used: Map.get(tx, "gasUsed", ""),
      transaction_index: Map.get(tx, "transactionIndex", ""),
      log_index: Map.get(tx, "logIndex", "")
    }
  end
end
