defmodule Lux.Web3.GasOptimizer.FeePredictor do
  @moduledoc """
  EIP-1559 gas price prediction and priority fee optimization engine.

  Analyzes `eth_feeHistory` base fee trajectories and priority-fee reward
  percentiles (`10th`, `50th`, `80th`, `95th`) to compute optimal fee parameters
  across `:economy`, `:standard`, `:fast`, and `:urgent` execution strategies.
  """

  @type tier :: :economy | :standard | :fast | :urgent

  @type prediction :: %{
          chain: atom(),
          tier: tier(),
          current_base_fee_wei: non_neg_integer(),
          predicted_next_base_fee_wei: non_neg_integer(),
          max_priority_fee_per_gas_wei: non_neg_integer(),
          max_fee_per_gas_wei: non_neg_integer(),
          network_congestion: float(),
          trend: :rising | :falling | :stable
        }

  @tier_multipliers %{
    economy: {0, 1.10},
    standard: {1, 1.25},
    fast: {2, 1.50},
    urgent: {3, 2.00}
  }

  @doc """
  Computes EIP-1559 fee predictions from an `eth_feeHistory` response map.
  """
  @spec analyze_fee_history(atom(), map(), tier()) :: {:ok, prediction()} | {:error, term()}
  def analyze_fee_history(chain, fee_history, tier \\ :standard)
      when is_atom(chain) and is_map(fee_history) do
    base_fees = Enum.map(fee_history["baseFeePerGas"] || [], &hex_to_int/1)
    gas_ratios = fee_history["gasUsedRatio"] || [0.5]
    rewards = fee_history["reward"] || []

    if base_fees == [] do
      {:error, :empty_fee_history}
    else
      current_base = List.last(base_fees)
      predicted_base = predict_next_base_fee(base_fees, gas_ratios)
      trend = classify_trend(base_fees)
      congestion = Float.round(Enum.sum(gas_ratios) / max(1, length(gas_ratios)), 4)

      {percentile_idx, base_multiplier} =
        Map.get(@tier_multipliers, tier, {1, 1.25})

      priority_fee = compute_priority_fee(rewards, percentile_idx, tier)
      max_fee = round(predicted_base * base_multiplier) + priority_fee

      {:ok,
       %{
         chain: chain,
         tier: tier,
         current_base_fee_wei: current_base,
         predicted_next_base_fee_wei: predicted_base,
         max_priority_fee_per_gas_wei: priority_fee,
         max_fee_per_gas_wei: max_fee,
         network_congestion: congestion,
         trend: trend
       }}
    end
  end

  @doc """
  Converts a hex quantity string or integer into a non-negative integer.
  """
  @spec hex_to_int(term()) :: non_neg_integer()
  def hex_to_int(val) when is_integer(val) and val >= 0, do: val

  def hex_to_int("0x" <> hex) when byte_size(hex) > 0 do
    case Integer.parse(hex, 16) do
      {num, ""} when num >= 0 -> num
      _ -> 0
    end
  end

  def hex_to_int(_), do: 0

  defp predict_next_base_fee(base_fees, gas_ratios) do
    latest = List.last(base_fees)
    avg_ratio = Enum.sum(gas_ratios) / max(1, length(gas_ratios))
    delta_factor = (avg_ratio - 0.5) / 0.5 * 0.125
    max(1_000_000_000, round(latest * (1.0 + delta_factor)))
  end

  defp classify_trend(base_fees) when length(base_fees) >= 2 do
    first = List.first(base_fees)
    last = List.last(base_fees)

    cond do
      last > first * 1.05 -> :rising
      last < first * 0.95 -> :falling
      true -> :stable
    end
  end

  defp classify_trend(_), do: :stable

  defp compute_priority_fee([], _idx, tier) do
    case tier do
      :economy -> 1_000_000_000
      :standard -> 1_500_000_000
      :fast -> 2_500_000_000
      :urgent -> 5_000_000_000
    end
  end

  defp compute_priority_fee(rewards, idx, _tier) do
    samples =
      rewards
      |> Enum.map(fn row ->
        row
        |> Enum.at(idx, List.last(row) || "0x59682f00")
        |> hex_to_int()
      end)
      |> Enum.filter(&(&1 > 0))

    if samples == [] do
      1_500_000_000
    else
      div(Enum.sum(samples), length(samples))
    end
  end
end
