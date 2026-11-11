defmodule Lux.Prisms.UniswapV3.RangeOptimizerPrism do
  @moduledoc """
  A prism that computes optimal Uniswap V3 liquidity tick boundaries based on
  realized volatility, TWAP divergence, fee tier, and target time-in-range horizon.
  """

  use Lux.Prism,
    name: "Uniswap V3 Range Optimizer",
    description: "Computes optimal Uniswap V3 concentrated liquidity range and rebalance triggers",
    input_schema: %{
      type: :object,
      properties: %{
        current_price: %{type: :number},
        twap_price: %{type: :number},
        daily_volatility: %{type: :number, description: "Daily price volatility as decimal (e.g. 0.035 for 3.5%)"},
        horizon_days: %{type: :number, description: "Target days before rebalancing"},
        confidence_sigma: %{type: :number, description: "Standard deviation multiplier (e.g. 2.0 for ~95%)"},
        fee_tier: %{type: :integer, enum: [100, 500, 3000, 10000]},
        existing_lower_price: %{type: :number},
        existing_upper_price: %{type: :number}
      },
      required: ["current_price", "daily_volatility", "fee_tier"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        optimal_lower_price: %{type: :number},
        optimal_upper_price: %{type: :number},
        optimal_tick_lower: %{type: :integer},
        optimal_tick_upper: %{type: :integer},
        should_rebalance: %{type: :boolean},
        rebalance_reason: %{type: :string},
        expected_range_width_pct: %{type: :number}
      },
      required: ["optimal_lower_price", "optimal_upper_price", "should_rebalance"]
    }

  alias Lux.Prisms.UniswapV3.PositionManagerPrism

  def handler(input, _ctx) do
    current_price = Map.fetch!(input, :current_price)
    twap_price = Map.get(input, :twap_price, current_price)
    daily_vol = max(Map.fetch!(input, :daily_volatility), 0.001)
    horizon_days = Map.get(input, :horizon_days, 7.0)
    sigma = Map.get(input, :confidence_sigma, 2.0)
    fee_tier = Map.fetch!(input, :fee_tier)

    # Geometric Brownian Motion range width over horizon_days
    period_vol = daily_vol * :math.sqrt(horizon_days) * sigma
    anchor_price = (current_price + twap_price) / 2.0

    raw_lower = anchor_price * :math.exp(-period_vol)
    raw_upper = anchor_price * :math.exp(period_vol)

    tick_lower = PositionManagerPrism.price_to_tick(raw_lower, fee_tier)
    tick_upper = PositionManagerPrism.price_to_tick(raw_upper, fee_tier)
    optimal_lower = Float.round(PositionManagerPrism.tick_to_price(tick_lower), 6)
    optimal_upper = Float.round(PositionManagerPrism.tick_to_price(tick_upper), 6)

    {should_rebalance, reason} =
      evaluate_rebalance(
        current_price,
        twap_price,
        Map.get(input, :existing_lower_price),
        Map.get(input, :existing_upper_price)
      )

    width_pct = Float.round((optimal_upper - optimal_lower) / anchor_price * 100.0, 2)

    {:ok,
     %{
       optimal_lower_price: optimal_lower,
       optimal_upper_price: optimal_upper,
       optimal_tick_lower: tick_lower,
       optimal_tick_upper: tick_upper,
       should_rebalance: should_rebalance,
       rebalance_reason: reason,
       expected_range_width_pct: width_pct
     }}
  end

  defp evaluate_rebalance(_p, _twap, nil, nil), do: {true, "initial_position_allocation"}

  defp evaluate_rebalance(p, twap, lower, upper) when is_number(lower) and is_number(upper) and upper > lower do
    twap_divergence = abs(p - twap) / max(twap, 1.0e-9)
    range_span = upper - lower
    edge_buffer = range_span * 0.10

    cond do
      twap_divergence > 0.03 ->
        {false, "twap_divergence_too_high_mev_protection"}

      p <= lower or p >= upper ->
        {true, "out_of_range"}

      p <= lower + edge_buffer or p >= upper - edge_buffer ->
        {true, "near_range_boundary_10pct"}

      true ->
        {false, "position_healthy_in_range"}
    end
  end
end
