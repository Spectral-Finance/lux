defmodule Lux.Prisms.Curve.CurvePoolPrism do
  @moduledoc """
  A prism that interfaces with Curve Finance stablecoin pools.
  """
  use Lux.Prism,
    name: "Curve Finance Pool Operations",
    description: "Execute add/remove liquidity on Curve pools",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["add_liquidity", "remove_liquidity"]},
        pool_address: %{type: :string},
        amounts: %{type: :array, items: %{type: :integer}},
        min_amount: %{type: :integer}
      },
      required: ["action", "pool_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        transaction: %{type: :object}
      },
      required: ["transaction"]
    }

  import Lux.Python
  alias Lux.Config

  def handler(%{"action" => "add_liquidity"} = input, _ctx) do
    pool_address = input["pool_address"]
    amounts = Map.get(input, "amounts", [0, 0, 0])
    min_mint_amount = Map.get(input, "min_amount", 0)

    with {:ok, address} <- {:ok, Config.wallet_address()},
         {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.pool"),
         {:ok, result} <- exec_add_liquidity(rpc_url, pool_address, amounts, min_mint_amount, address) do
      {:ok, %{transaction: result}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(%{"action" => "remove_liquidity"} = input, _ctx) do
    pool_address = input["pool_address"]
    amount = Map.get(input, "amount", 0)
    min_amounts = Map.get(input, "min_amounts", [0, 0, 0])

    with {:ok, address} <- {:ok, Config.wallet_address()},
         {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.pool"),
         {:ok, result} <- exec_remove_liquidity(rpc_url, pool_address, amount, min_amounts, address) do
      {:ok, %{transaction: result}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp exec_add_liquidity(rpc_url, pool_address, amounts, min_mint_amount, address) do
    python_result =
      python variables: %{rpc_url: rpc_url, pool_address: pool_address, amounts: amounts, min_mint_amount: min_mint_amount, address: address} do
        ~PY"""
        from web3 import Web3
        from curve_utils.pool import add_liquidity

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        tx = add_liquidity(w3, pool_address, amounts, min_mint_amount, address)
        tx
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp exec_remove_liquidity(rpc_url, pool_address, amount, min_amounts, address) do
    python_result =
      python variables: %{rpc_url: rpc_url, pool_address: pool_address, amount: amount, min_amounts: min_amounts, address: address} do
        ~PY"""
        from web3 import Web3
        from curve_utils.pool import remove_liquidity

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        tx = remove_liquidity(w3, pool_address, amount, min_amounts, address)
        tx
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
