defmodule Lux.Web3.Gas.Predictor do
  @moduledoc """
  EIP-1559 gas price prediction and priority fee optimization engine.

  Provides algorithms for:
  - Next-block base fee computation using Ethereum EIP-1559 elasticity formula
  - Moving average & exponential smoothing of recent block fees
  - Network congestion classification (low, medium, high, extreme)
  - Priority fee (tip) optimization across 4 urgency tiers (:slow, :standard, :fast, :instant)
  - Optimal execution window recommendation
  """

  @eip1559_elasticity_multiplier 2
  @eip1559_base_fee_max_change_denominator 8
  @wei_per_gwei 1_000_000_000

  @type speed_tier :: :slow | :standard | :fast | :instant
  @type congestion_level :: :low | :medium | :high | :extreme

  @type gas_recommendation :: %{
          base_fee_gwei: float(),
          max_priority_fee_gwei: float(),
          max_fee_gwei: float(),
          base_fee_wei: pos_integer(),
          max_priority_fee_wei: pos_integer(),
          max_fee_wei: pos_integer(),
          estimated_wait_seconds: non_neg_integer(),
          congestion_level: congestion_level()
        }

  @doc """
  Calculates the exact next block base fee according to the EIP-1559 consensus rule.

  ## Parameters:
    - `current_base_fee`: Current block base fee in Wei.
    - `gas_used`: Total gas consumed in the current block.
    - `gas_limit`: Total block gas limit.
  """
  @spec calculate_next_base_fee(pos_integer(), non_neg_integer(), pos_integer()) :: pos_integer()
  def calculate_next_base_fee(current_base_fee, gas_used, gas_limit)
      when is_integer(current_base_fee) and is_integer(gas_used) and is_integer(gas_limit) and
             gas_limit > 0 do
    target_gas = div(gas_limit, @eip1559_elasticity_multiplier)

    cond do
      gas_used == target_gas ->
        current_base_fee

      gas_used > target_gas ->
        gas_delta = gas_used - target_gas
        fee_delta = div(current_base_fee * gas_delta, target_gas * @eip1559_base_fee_max_change_denominator)
        fee_delta = max(fee_delta, 1)
        current_base_fee + fee_delta

      gas_used < target_gas ->
        gas_delta = target_gas - gas_used
        fee_delta = div(current_base_fee * gas_delta, target_gas * @eip1559_base_fee_max_change_denominator)
        max(current_base_fee - fee_delta, 0)
    end
  end

  @doc """
  Computes network congestion level based on block utilization percentage.
  """
  @spec assess_congestion(non_neg_integer(), pos_integer()) :: congestion_level()
  def assess_congestion(gas_used, gas_limit) when gas_limit > 0 do
    utilization = gas_used / gas_limit

    cond do
      utilization < 0.40 -> :low
      utilization < 0.70 -> :medium
      utilization < 0.90 -> :high
      true -> :extreme
    end
  end

  @doc """
  Estimates priority fees (tips) and total max fee for a given urgency tier.

  ## Options:
    - `:history`: list of recent blocks with `%{base_fee: integer(), gas_used: integer(), gas_limit: integer(), tips: [integer()]}`
    - `:fallback_base_fee_gwei`: fallback base fee if history is empty (default 20.0)
  """
  @spec predict_fees(speed_tier(), list(map()) | map()) :: gas_recommendation()
  def predict_fees(tier \\ :standard, opts \\ %{})

  def predict_fees(tier, opts) when is_list(opts) do
    predict_fees(tier, Map.new(opts))
  end

  def predict_fees(tier, opts) when is_map(opts) do
    history = Map.get(opts, :history, [])
    fallback_base_fee = Map.get(opts, :fallback_base_fee_gwei, 25.0)

    {current_base_wei, congestion} =
      case history do
        [latest | _] ->
          gas_used = Map.get(latest, :gas_used, 15_000_000)
          gas_limit = Map.get(latest, :gas_limit, 30_000_000)
          base_fee = Map.get(latest, :base_fee, round(fallback_base_fee * @wei_per_gwei))
          next_base = calculate_next_base_fee(base_fee, gas_used, gas_limit)
          {next_base, assess_congestion(gas_used, gas_limit)}

        [] ->
          {round(fallback_base_fee * @wei_per_gwei), :medium}
      end

    {priority_multiplier, base_fee_multiplier, wait_sec} =
      case tier do
        :slow -> {1.0, 1.05, 120}
        :standard -> {1.5, 1.15, 30}
        :fast -> {2.5, 1.25, 12}
        :instant -> {4.0, 1.50, 0}
      end

    congestion_surge =
      case congestion do
        :low -> 0.9
        :medium -> 1.0
        :high -> 1.2
        :extreme -> 1.5
      end

    tip_gwei =
      extract_median_tip(history)
      |> Kernel.*(priority_multiplier)
      |> Kernel.*(congestion_surge)
      |> Float.round(3)
      |> max(1.0)

    base_fee_gwei = Float.round(current_base_wei / @wei_per_gwei, 3)
    max_fee_gwei = Float.round(base_fee_gwei * base_fee_multiplier + tip_gwei, 3)

    priority_wei = round(tip_gwei * @wei_per_gwei)
    max_fee_wei = round(max_fee_gwei * @wei_per_gwei)

    %{
      base_fee_gwei: base_fee_gwei,
      max_priority_fee_gwei: tip_gwei,
      max_fee_gwei: max_fee_gwei,
      base_fee_wei: current_base_wei,
      max_priority_fee_wei: priority_wei,
      max_fee_wei: max_fee_wei,
      estimated_wait_seconds: wait_sec,
      congestion_level: congestion
    }
  end

  @doc """
  Calculates exponential moving average (EMA) of historical base fees.
  """
  @spec calculate_base_fee_ema(list(number()), float()) :: float()
  def calculate_base_fee_ema([], _alpha), do: 0.0
  def calculate_base_fee_ema([first | rest], alpha) when alpha > 0 and alpha <= 1 do
    Enum.reduce(rest, first * 1.0, fn val, ema ->
      alpha * val + (1.0 - alpha) * ema
    end)
  end

  @doc """
  Identifies whether the current network base fee is in a favorable dip
  compared to the historical average (useful for scheduling delayed non-critical transactions).
  """
  @spec is_favorable_window?(pos_integer(), list(pos_integer()), float()) :: boolean()
  def is_favorable_window?(_current_fee, [], _threshold_discount), do: true

  def is_favorable_window?(current_fee, historical_fees, threshold_discount) do
    avg = Enum.sum(historical_fees) / length(historical_fees)
    current_fee <= avg * (1.0 - threshold_discount)
  end

  defp extract_median_tip(history) when is_list(history) and length(history) > 0 do
    tips =
      Enum.flat_map(history, fn block ->
        Map.get(block, :tips, [1.5])
      end)
      |> Enum.sort()

    case tips do
      [] -> 1.5
      sorted ->
        mid = div(length(sorted), 2)
        Enum.at(sorted, mid, 1.5) * 1.0
    end
  end

  defp extract_median_tip(_), do: 1.5
end
