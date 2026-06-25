defmodule Lux.Prisms.Curve.CurveSwapPrism do
  @moduledoc """
  A prism that swaps tokens on a Curve Finance pool.

  ## Example

      iex> Lux.Prisms.Curve.CurveSwapPrism.run(%{
      ...>   pool_name: "3crypto",
      ...>   coin_from: 0,
      ...>   coin_to: 1,
      ...>   amount: "1000000000000000000000",
      ...>   expected: "990000000000000000000"
      ...> })
      {:ok, %{tx_hash: "0x...", pool: "3crypto", ...}}
  """

  use Lux.Prism,
    name: "Curve Swap",
    description: "Swaps tokens between two assets in a Curve Finance pool",
    input_schema: %{
      type: :object,
      properties: %{
        pool_name: %{type: :string, description: "The name of the Curve pool"},
        coin_from: %{type: :integer, description: "Index of the source coin (0-based)"},
        coin_to: %{type: :integer, description: "Index of the destination coin (0-based)"},
        amount: %{type: :string, description: "Amount of source token to swap (in wei)"},
        expected: %{type: :string, description: "Minimum amount of destination token expected (slippage protection)"},
        account: %{type: :string, description: "Optional account address"}
      },
      required: ["pool_name", "coin_from", "coin_to", "amount", "expected"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        pool: %{type: :string, description: "Pool name"},
        coin_from: %{type: :integer},
        coin_to: %{type: :integer},
        amount_in: %{type: :string},
        amount_out: %{type: :string}
      },
      required: ["tx_hash", "pool", "coin_from", "coin_to", "amount_in"]
    },
    examples: ["Swap 1000 USDC for DAI in the 3crypto pool"]

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- get_address(),
         {:ok, rpc_url} <- {:ok, Lux.Integrations.Curve.rpc_url()},
         {:ok, chain_id} <- {:ok, Lux.Integrations.Curve.chain_id()},
         {:ok, result} <- execute_swap(private_key, address, rpc_url, chain_id, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} -> {:error, "Ethereum private key is not configured for Curve transactions"}
      {:error, :missing_rpc_url} -> {:error, "Curve RPC URL is not configured"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_private_key do
    case Application.get_env(:ethers, :default_signer_opts, [])[:private_key] do
      nil ->
        case Application.get_env(:lux, :accounts, [])[:hyperliquid_private_key] do
          nil -> {:error, :missing_private_key}
          key when is_binary(key) -> {:ok, key}
        end
      key when is_binary(key) -> {:ok, key}
    end
  rescue
    _ ->
      case Application.get_env(:ethers, :default_signer_opts, [])[:private_key] do
        nil -> {:error, :missing_private_key}
        key when is_binary(key) -> {:ok, key}
      end
  end

  defp get_address do
    case Application.get_env(:lux, :accounts, [])[:hyperliquid_address] do
      nil ->
        case Application.get_env(:lux, :accounts, [])[:wallet_address] do
          nil -> {:ok, ""}
          addr when is_binary(addr) -> {:ok, addr}
        end
      addr when is_binary(addr) -> {:ok, addr}
    end
  end

  defp execute_swap(private_key, address, rpc_url, chain_id, params) do
    python_code = File.read!(Path.join(__DIR__, "../../../priv/python/curve_swap.py"))

    python_result =
      python variables: %{private_key: private_key, address: address, rpc_url: rpc_url, chain_id: chain_id, params: params} do
        ~PY"""
        #{python_code}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      result -> {:ok, %{tx_hash: to_string(result), pool: params["pool_name"]}}
    end
  end
end
