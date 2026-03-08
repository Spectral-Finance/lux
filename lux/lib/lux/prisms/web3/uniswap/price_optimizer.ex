defmodule Lux.Prisms.Web3.Uniswap.PriceOptimizer do
  @moduledoc """
  Price range optimization and fee tier selection for Uniswap V3.

  Provides:
  - Fee tier recommendation based on volatility, correlation, volume
  - Price range optimization with tight/balanced/wide strategies
  - Capital efficiency calculation
  - Impermanent loss calculation

  ## Example

      {:ok, rec} = PriceOptimizer.recommend_fee_tier(%{volatility: :medium})
      {:ok, range} = PriceOptimizer.optimize_range(%{current_price: 2000.0, strategy: :balanced})
      {:ok, il} = PriceOptimizer.calculate_il(100.0, 150.0)
  """

  @type fee_tier :: 100 | 500 | 3000 | 10_000

  @fee_tiers %{
    100 => %{name: "0.01%", best_for: :stable_pairs, spread_multiplier: 1.001},
    500 => %{name: "0.05%", best_for: :correlated, spread_multiplier: 1.005},
    3000 => %{name: "0.3%", best_for: :standard, spread_multiplier: 1.03},
    10_000 => %{name: "1%", best_for: :exotic, spread_multiplier: 1.10}
  }

  @valid_strategies [:tight, :balanced, :wide]
  @valid_volatilities [:low, :medium, :high]

  @doc "Recommend optimal fee tier based on pair characteristics."
  @spec recommend_fee_tier(map()) :: {:ok, map()} | {:error, atom()}
  def recommend_fee_tier(params) do
    volatility = params[:volatility] || :medium
    correlation = params[:correlation] || 0.5

    unless volatility in @valid_volatilities do
      {:error, :invalid_volatility}
    else
      tier = cond do
        correlation > 0.95 -> 100
        correlation > 0.8 -> 500
        volatility == :low && (params[:daily_volume] || 0) > 1_000_000 -> 500
        volatility == :high -> 10_000
        true -> 3000
      end

      {:ok, %{
        recommended_tier: tier,
        tier_info: @fee_tiers[tier],
        all_tiers: @fee_tiers,
        reasoning: fee_reasoning(tier)
      }}
    end
  end

  @doc "Optimize price range for a position."
  @spec optimize_range(map()) :: {:ok, map()} | {:error, atom()}
  def optimize_range(params) do
    current_price = params[:current_price]
    volatility = params[:volatility] || :medium
    strategy = params[:strategy] || :balanced

    cond do
      is_nil(current_price) -> {:error, :missing_price}
      current_price <= 0 -> {:error, :invalid_price}
      strategy not in @valid_strategies -> {:error, :invalid_strategy}
      volatility not in @valid_volatilities -> {:error, :invalid_volatility}
      true ->
        {lower_mult, upper_mult} = range_multipliers(strategy, volatility)

        price_lower = Float.round(current_price * lower_mult, 6)
        price_upper = Float.round(current_price * upper_mult, 6)
        width = upper_mult - lower_mult
        capital_efficiency = if width > 0, do: Float.round(1 / width, 2), else: 0.0

        {:ok, %{
          price_lower: price_lower,
          price_upper: price_upper,
          current_price: current_price,
          range_width_pct: Float.round(width * 100, 2),
          capital_efficiency: capital_efficiency,
          strategy: strategy,
          estimated_apr_multiplier: capital_efficiency
        }}
    end
  end

  @doc "Calculate impermanent loss for a price change."
  @spec calculate_il(number(), number()) :: {:ok, map()} | {:error, atom()}
  def calculate_il(initial_price, _current_price) when initial_price <= 0, do: {:error, :invalid_price}
  def calculate_il(_initial_price, current_price) when current_price <= 0, do: {:error, :invalid_price}
  def calculate_il(initial_price, current_price) do
    ratio = current_price / initial_price
    il = 2 * :math.sqrt(ratio) / (1 + ratio) - 1

    {:ok, %{
      price_ratio: Float.round(ratio, 4),
      il_percentage: Float.round(abs(il) * 100, 4),
      il_raw: Float.round(il, 6),
      direction: if(ratio >= 1, do: :price_up, else: :price_down),
      hold_value_ratio: Float.round(ratio, 4),
      lp_value_ratio: Float.round(2 * :math.sqrt(ratio) / (1 + ratio), 4)
    }}
  end

  @doc "Compare IL across multiple price scenarios."
  @spec il_scenarios(number(), [number()]) :: {:ok, [map()]}
  def il_scenarios(initial_price, target_prices) when is_list(target_prices) do
    results = Enum.map(target_prices, fn tp ->
      {:ok, il} = calculate_il(initial_price, tp)
      Map.put(il, :target_price, tp)
    end)
    {:ok, results}
  end

  # --- Private ---

  defp range_multipliers(:tight, :low), do: {0.995, 1.005}
  defp range_multipliers(:tight, _), do: {0.98, 1.02}
  defp range_multipliers(:balanced, :low), do: {0.95, 1.05}
  defp range_multipliers(:balanced, :medium), do: {0.90, 1.10}
  defp range_multipliers(:balanced, :high), do: {0.80, 1.20}
  defp range_multipliers(:wide, _), do: {0.70, 1.30}
  defp range_multipliers(_, _), do: {0.90, 1.10}

  defp fee_reasoning(100), do: "Stable pair — minimal fee captures tight spreads"
  defp fee_reasoning(500), do: "Correlated pair — low fee with moderate range"
  defp fee_reasoning(3000), do: "Standard pair — balanced fee for most trading pairs"
  defp fee_reasoning(10_000), do: "Exotic/volatile pair — high fee compensates for IL risk"
  defp fee_reasoning(_), do: "Default recommendation"
end
