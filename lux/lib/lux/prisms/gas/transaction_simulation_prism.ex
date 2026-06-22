defmodule Lux.Prisms.Gas.TransactionSimulationPrism do
  @moduledoc """
  Simulates Ethereum transactions to estimate gas costs and detect failures before broadcast.
  """

  use Lux.Prism,
    name: "Transaction Simulator",
    description: "Simulates Ethereum transactions to estimate gas costs and detect failures",
    input_schema: %{
      type: :object,
      properties: %{
        to: %{type: :string, description: "Recipient address", pattern: "^0x[a-fA-F0-9]{40}$"},
        value: %{type: :string, default: "0"},
        data: %{type: :string, default: "0x"},
        from: %{type: :string, description: "Sender address for simulation"},
        gas_price_gwei: %{type: :number},
        network: %{type: :string, enum: ["mainnet", "goerli", "sepolia"], default: "mainnet"}
      },
      required: ["to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        simulated: %{type: :boolean},
        estimated_gas: %{type: :integer},
        estimated_cost_wei: %{type: :integer},
        estimated_cost_eth: %{type: :number},
        success: %{type: :boolean},
        revert_reason: %{type: :string},
        network: %{type: :string}
      },
      required: ["simulated", "estimated_gas", "estimated_cost_wei", "estimated_cost_eth", "success", "network"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  @gwei 1_000_000_000

  def handler(input, _ctx \ nil) do
    to = Map.get(input, :to)
    value = Map.get(input, :value, "0")
    data = Map.get(input, :data, "0x")
    from = Map.get(input, :from)
    gas_price_gwei = Map.get(input, :gas_price_gwei)
    network = Map.get(input, :network, "mainnet")

    unless to && is_binary(to) do
      {:error, "Recipient address (to) is required"}
    else
      with {:ok, _} <- Lux.Python.import_package("web3"),
           {:ok, result} <- do_simulate(to, value, data, from, gas_price_gwei, network) do
        {:ok, atomize_keys(result)}
      else
        {:ok, %{"success" => false, "error" => error}} ->
          {:error, "Web3 import failed: #{error}"}
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_simulate(to, value, data, from, gas_price_gwei, network) do
    api_key = Config.alchemy_api_key()

    result =
      python variables: %{to: to, value: value, data: data, from: from || "", network: network, api_key: api_key, gas_price_gwei: gas_price_gwei} do
        ~PY"""
        from web3 import Web3
        NETWORKS = {"mainnet": f"https://eth-mainnet.g.alchemy.com/v2/{api_key}", "goerli": f"https://eth-goerli.g.alchemy.com/v2/{api_key}", "sepolia": f"https://eth-sepolia.g.alchemy.com/v2/{api_key}"}
        url = NETWORKS.get(network, NETWORKS["mainnet"])
        w3 = Web3(Web3.HTTPProvider(url))
        tx = {"to": Web3.to_checksum_address(to), "value": int(value, 16) if value.startswith("0x") else int(value), "data": data if data.startswith("0x") else "0x" + data}
        if from and from != "": tx["from"] = Web3.to_checksum_address(from)
        try:
            estimated_gas = w3.eth.estimate_gas(tx)
            try:
                w3.eth.call(tx)
                success, revert_reason = True, None
            except Exception as e:
                success, error_str = False, str(e)
                revert_reason = "Contract execution reverted" if "execution reverted" in error_str.lower() else error_str[:200]
            gp = gas_price_gwei if gas_price_gwei else 30
            cost_wei = estimated_gas * int(gp * 1e9)
            {"estimated_gas": estimated_gas, "success": success, "revert_reason": revert_reason, "estimated_cost_wei": cost_wei, "estimated_cost_eth": round(cost_wei / 1e18, 6)}
        except Exception as e:
            {"estimated_gas": 21000, "success": False, "revert_reason": str(e)[:200], "estimated_cost_wei": 21000 * 30000000000, "estimated_cost_eth": 0.00063}
        """
      end

    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
