defmodule Lux.Prisms.Curve.CurveGaugePrism do
  @moduledoc """
  A prism that interfaces with Curve Finance Liquidity Gauges.
  """
  use Lux.Prism,
    name: "Curve Finance Gauge Operations",
    description: "Deposit or withdraw LP tokens from Curve gauges",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["deposit", "withdraw", "claim_rewards"]},
        gauge_address: %{type: :string},
        amount: %{type: :integer}
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

  def handler(%{"action" => "deposit"} = input, _ctx) do
    gauge_address = input["gauge_address"]
    amount = Map.get(input, "amount", 0)

    with {:ok, address} <- {:ok, Config.wallet_address()},
         {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.gauge"),
         {:ok, result} <- exec_deposit(rpc_url, gauge_address, amount, address) do
      {:ok, %{transaction: result}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(%{"action" => "withdraw"} = input, _ctx) do
    gauge_address = input["gauge_address"]
    amount = Map.get(input, "amount", 0)

    with {:ok, address} <- {:ok, Config.wallet_address()},
         {:ok, rpc_url} <- {:ok, Lux.Config.resolve({:runtime_config, :lux, [:accounts, :evm_rpc_url], "https://eth.llamarpc.com"})},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("curve_utils.gauge"),
         {:ok, result} <- exec_withdraw(rpc_url, gauge_address, amount, address) do
      {:ok, %{transaction: result}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

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

  defp exec_deposit(rpc_url, gauge_address, amount, address) do
    python_result =
      python variables: %{rpc_url: rpc_url, gauge_address: gauge_address, amount: amount, address: address} do
        ~PY"""
        from web3 import Web3
        import sys
        import os
        sys.path.append(os.getcwd() + '/priv/python')
        from curve_utils.gauge import deposit

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        tx = deposit(w3, gauge_address, amount, address)
        tx
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp exec_withdraw(rpc_url, gauge_address, amount, address) do
    python_result =
      python variables: %{rpc_url: rpc_url, gauge_address: gauge_address, amount: amount, address: address} do
        ~PY"""
        from web3 import Web3
        import sys
        import os
        sys.path.append(os.getcwd() + '/priv/python')
        from curve_utils.gauge import withdraw

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        tx = withdraw(w3, gauge_address, amount, address)
        tx
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
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
