defmodule Lux.Prisms.GasOptimizationPrism do
  @moduledoc """
  Gas optimization prism that wraps the gas management system.
  """

  use Lux.Prism,
    name: "Gas Optimization",
    description: "Analyzes and optimizes gas costs for transactions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["predict", "simulate", "batch", "mev", "report"],
          default: "predict"
        },
        network: %{
          type: :string,
          enum: ["mainnet", "goerli", "sepolia"],
          default: "mainnet"
        },
        transaction: %{type: :object},
        transactions: %{type: :array},
        nonce: %{type: :integer}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Web3.Gas

  def handler(%{action: "predict"} = input, _context) do
    network = Map.get(input, :network, "mainnet")
    case Gas.predict_price(network: network) do
      {:ok, recommendation} ->
        {:ok, %{action: "predict", result: Map.from_struct(recommendation)}}
      {:error, reason} ->
        {:error, "Gas prediction failed: #{inspect(reason)}"}
    end
  end

  def handler(%{action: "simulate", transaction: tx} = input, _context) do
    network = Map.get(input, :network, "mainnet")
    tx_with_network = Map.put(tx, :network, network)
    case Gas.simulate(tx_with_network) do
      {:ok, result} ->
        {:ok, %{action: "simulate", result: Map.from_struct(result)}}
      {:error, reason} ->
        {:error, "Simulation failed: #{inspect(reason)}"}
    end
  end

  def handler(%{action: "batch", transactions: txns, nonce: nonce}, _context) do
    case Gas.create_batch(txns, nonce: nonce) do
      {:ok, batch} ->
        {:ok, %{action: "batch", result: Map.from_struct(batch)}}
      {:error, reason} ->
        {:error, "Batch creation failed: #{inspect(reason)}"}
    end
  end

  def handler(%{action: "mev", transaction: tx}, _context) do
    case Gas.analyze_mev(tx) do
      {:ok, analysis} ->
        {:ok, %{action: "mev", result: Map.from_struct(analysis)}}
      {:error, reason} ->
        {:error, "MEV analysis failed: #{inspect(reason)}"}
    end
  end

  def handler(%{action: "report", transactions: txns, period: period}, _context) do
    case Gas.cost_report(txns, period) do
      {:ok, report} ->
        {:ok, %{action: "report", result: Map.from_struct(report)}}
      {:error, reason} ->
        {:error, "Report generation failed: #{inspect(reason)}"}
    end
  end

  def handler(%{action: action}, _context),
    do: {:error, "Unknown gas optimization action: #{inspect(action)}"}
end
