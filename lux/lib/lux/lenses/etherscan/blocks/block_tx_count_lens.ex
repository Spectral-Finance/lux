defmodule Lux.Lenses.Etherscan.BlockTxCount do
  @moduledoc """
  Lens for fetching the number of transactions in a specified block from the Etherscan API.

  Note: This endpoint is only available on Etherscan, `chainId` 1.

  ## Examples

  ```elixir
  # Get transaction count for a specific block
  Lux.Lenses.Etherscan.BlockTxCount.focus(%{
    blockno: 2165403
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BlockTxCount",
    description: "Fetches the number of transactions in a specified block",
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
          description: "Network identifier (must be 1 for Ethereum mainnet only)",
          default: 1
        },
        blockno: %{
          type: [:integer, :string],
          description: "Block height to analyze transaction counts for"
        }
      },
      required: ["blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Validate that chainid is 1 (only supported on Ethereum mainnet)
    chainid = Map.get(params, :chainid, 1)
    unless chainid == 1 do
      raise "This endpoint is only available on Etherscan (chainId 1)"
    end

    # Convert blockno to string if it's an integer
    params = case params[:blockno] do
      blockno when is_integer(blockno) -> Map.put(params, :blockno, to_string(blockno))
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "block")
    |> Map.put(:action, "getblocktxnscount")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_map(result) ->
        # Return a structured response with the transaction counts
        {:ok, %{
          result: %{
            block_number: Map.get(result, "block", ""),
            transactions_count: Map.get(result, "txsCount", 0),
            internal_transactions_count: Map.get(result, "internalTxsCount", 0),
            erc20_transactions_count: Map.get(result, "erc20TxsCount", 0),
            erc721_transactions_count: Map.get(result, "erc721TxsCount", 0),
            erc1155_transactions_count: Map.get(result, "erc1155TxsCount", 0)
          }
        }}
      {:ok, %{result: result}} when is_binary(result) ->
        # Handle the case where the result is just a string (older API version)
        {:ok, %{
          result: %{
            transactions_count: result
          }
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
