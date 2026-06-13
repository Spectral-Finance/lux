defmodule Lux.Prisms.Pancakeswap.PancakeswapSwapPrism do
  @moduledoc """
  A prism that executes token swaps on PancakeSwap V2/V3.

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapSwapPrism.handler(%{
      ...>   token_in: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   token_out: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_in: "1000000000000000000",
      ...>   chain_id: 56,
      ...>   slippage: 50
      ...> }, %{})

  Reads config:
  - :pancakeswap_private_key - wallet private key
  - :bsc_rpc_url - BSC RPC endpoint
  """

  use Lux.Prism,
    name: "PancakeSwap Token Swap",
    description: "Executes token swaps on PancakeSwap V2/V3 DEX",
    input_schema: %{
      type: :object,
      properties: %{
        token_in: %{type: :string, description: "Input token contract address"},
        token_out: %{type: :string, description: "Output token contract address"},
        amount_in: %{type: :string, description: "Amount to swap in wei"},
        chain_id: %{type: :integer, description: "Chain ID (56=BSC Mainnet, 97=BSC Testnet)", default: 56},
        slippage: %{type: :integer, description: "Slippage tolerance in basis points (50 = 0.5%)", default: 50}
      },
      required: ["token_in", "token_out", "amount_in"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        amount_out: %{type: :string, description: "Amount of tokens received"},
        status: %{type: :string}
      },
      required: ["tx_hash", "amount_out", "status"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  alias Lux.Config

  def handler(input, _ctx) do
    input = Map.put_new(input, :chain_id, 56)
    input = Map.put_new(input, :slippage, 50)

    with {:ok, private_key} <- get_private_key(),
         {:ok, rpc_url} <- get_rpc_url(input.chain_id),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("pancakeswap_python"),
         {:ok, result} <- execute_swap(private_key, rpc_url, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "PancakeSwap private key is not configured"}
      {:error, :missing_rpc_url} ->
        {:error, "BSC RPC URL is not configured"}
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import required packages: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    case Config.pancakeswap_private_key() do
      nil -> {:error, :missing_private_key}
      key -> {:ok, key}
    end
  rescue
    _ -> {:error, :missing_private_key}
  end

  defp get_rpc_url(56), do: {:ok, "https://bsc-dataseed.binance.org/"}
  defp get_rpc_url(97), do: {:ok, "https://data-seed-prebsc-1-s1.binance.org:8545/"}
  defp get_rpc_url(_), do: {:error, :missing_rpc_url}

  defp execute_swap(private_key, rpc_url, params) do
    python_result =
      python variables: %{
               private_key: private_key,
               rpc_url: rpc_url,
               token_in: params.token_in,
               token_out: params.token_out,
               amount_in: params.amount_in,
               slippage: params.slippage
             } do
        ~PY"""
        result = None
        try:
            from web3 import Web3
            from pancakeswap_python import PancakeSwap

            w3 = Web3(Web3.HTTPProvider(rpc_url))
            account = w3.eth.account.from_key(private_key)

            pancake = PancakeSwap(
                address=account.address,
                private_key=private_key,
                web3=w3
            )

            slippage_pct = slippage / 10000

            tx_hash = pancake.make_trade(
                input_token=token_in,
                output_token=token_out,
                qty=int(amount_in),
                slippage=slippage_pct
            )

            amount_out = pancake.get_token_price(token_in, token_out, int(amount_in))

            result = {
                "tx_hash": tx_hash.hex() if hasattr(tx_hash, 'hex') else str(tx_hash),
                "amount_out": str(amount_out),
                "status": "success"
            }
        except Exception as e:
            result = {"error": str(e)}
        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      %{"tx_hash" => _, "amount_out" => _, "status" => _} = res -> {:ok, res}
    end
  end
end
