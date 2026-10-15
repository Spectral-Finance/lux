defmodule Lux.Prisms.Web3.GasOptimizerPrism do
  @moduledoc """
  Lux Prism exposing EIP-1559 gas fee prediction, Multicall3 transaction
  batching, RBF speed-up/cancel replacement, MEV risk analysis, pre-flight
  transaction simulation, and cost reporting.
  """

  use Lux.Prism,
    name: "Gas Optimizer & Transaction Manager",
    description: "Optimizes gas fees, batches calls, simulates transactions, and prevents MEV",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Gas optimizer action to execute"
        },
        chain: %{type: :string},
        tier: %{type: :string},
        calls: %{type: :array, items: %{type: :object}},
        transaction: %{type: :object}
      },
      required: ["action"]
    }

  alias Lux.Web3.GasOptimizer

  @impl true
  def handler(params, _ctx) when is_map(params) do
    action = Map.get(params, "action") || Map.get(params, :action)
    dispatch(to_string(action), normalize_keys(params))
  end

  defp dispatch("predict_fees", params) do
    chain = parse_chain(Map.get(params, :chain, :ethereum))
    tier = parse_tier(Map.get(params, :tier, :standard))
    GasOptimizer.predict_gas_fees(chain, tier)
  end

  defp dispatch("build_batch", %{calls: calls}) when is_list(calls) do
    GasOptimizer.build_batch(calls)
  end

  defp dispatch("speed_up", %{transaction: tx}) when is_map(tx) do
    GasOptimizer.speed_up(normalize_keys(tx))
  end

  defp dispatch("cancel", %{transaction: tx}) when is_map(tx) do
    GasOptimizer.cancel(normalize_keys(tx))
  end

  defp dispatch("analyze_mev", %{transaction: tx}) when is_map(tx) do
    {:ok, GasOptimizer.analyze_mev_risk(normalize_keys(tx))}
  end

  defp dispatch("simulate", %{transaction: tx}) when is_map(tx) do
    GasOptimizer.simulate_transaction(normalize_keys(tx))
  end

  defp dispatch("cost_report", _params) do
    {:ok, GasOptimizer.cost_report()}
  end

  defp dispatch(other, _params), do: {:error, {:unsupported_action, other}}

  defp parse_chain(c) when is_atom(c), do: c
  defp parse_chain("polygon"), do: :polygon
  defp parse_chain("bsc"), do: :bsc
  defp parse_chain("arbitrum"), do: :arbitrum
  defp parse_chain("optimism"), do: :optimism
  defp parse_chain("base"), do: :base
  defp parse_chain(_), do: :ethereum

  defp parse_tier(t) when is_atom(t), do: t
  defp parse_tier("economy"), do: :economy
  defp parse_tier("fast"), do: :fast
  defp parse_tier("urgent"), do: :urgent
  defp parse_tier(_), do: :standard

  defp normalize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
