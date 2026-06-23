defmodule Lux.Prisms.Curve.CurveRewardsPrism do
  @moduledoc """
  A prism that interfaces with Curve Finance to claim rewards.
  """
  use Lux.Prism,
    name: "Curve Finance Rewards Operations",
    description: "Claim rewards from Curve gauges",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["claim_rewards"]},
        gauge_address: %{type: :string}
      },
      required: ["action", "gauge_address"]
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

  def handler(%{"action" => "claim_rewards"} = input, _ctx) do
    gauge_address = input["gauge_address"]

    with {:ok, address} <- {:ok, Config.wallet_address()},
         {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.gauge"),
         {:ok, result} <- exec_claim_rewards(rpc_url, gauge_address, address) do
      {:ok, %{transaction: result}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp exec_claim_rewards(rpc_url, gauge_address, address) do
    python_result =
      python variables: %{rpc_url: rpc_url, gauge_address: gauge_address, address: address} do
        ~PY"""
        from web3 import Web3
        import sys
        import os
        sys.path.append(os.getcwd() + '/priv/python')
        from curve_utils.gauge import claim_rewards

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        tx = claim_rewards(w3, gauge_address, address)
        tx
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
