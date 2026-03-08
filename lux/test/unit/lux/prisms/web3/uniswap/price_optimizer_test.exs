defmodule Lux.Prisms.Web3.Uniswap.PriceOptimizerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Uniswap.PriceOptimizer

  # --- Fee Tier Recommendation ---

  test "recommend fee tier for stable pair (high correlation)" do
    {:ok, r} = PriceOptimizer.recommend_fee_tier(%{correlation: 0.99})
    assert r.recommended_tier == 100
    assert r.reasoning =~ "Stable"
  end

  test "recommend fee tier for correlated pair" do
    {:ok, r} = PriceOptimizer.recommend_fee_tier(%{correlation: 0.85})
    assert r.recommended_tier == 500
  end

  test "recommend fee tier for standard pair" do
    {:ok, r} = PriceOptimizer.recommend_fee_tier(%{volatility: :medium})
    assert r.recommended_tier == 3000
  end

  test "recommend fee tier for volatile pair" do
    {:ok, r} = PriceOptimizer.recommend_fee_tier(%{volatility: :high})
    assert r.recommended_tier == 10_000
  end

  test "recommend fee tier includes all tiers info" do
    {:ok, r} = PriceOptimizer.recommend_fee_tier(%{})
    assert map_size(r.all_tiers) == 4
  end

  # --- Range Optimization ---

  test "optimize tight range low volatility" do
    {:ok, r} = PriceOptimizer.optimize_range(%{current_price: 2000.0, strategy: :tight, volatility: :low})
    assert r.price_lower >= 1990
    assert r.price_upper <= 2010
    assert r.capital_efficiency >= 100
    assert r.strategy == :tight
  end

  test "optimize balanced medium volatility" do
    {:ok, r} = PriceOptimizer.optimize_range(%{current_price: 100.0, volatility: :medium})
    assert r.range_width_pct == 20.0
    assert r.price_lower == 90.0
    assert r.price_upper == 110.0
  end

  test "optimize wide range" do
    {:ok, r} = PriceOptimizer.optimize_range(%{current_price: 2000.0, strategy: :wide})
    assert r.price_lower < 1500
    assert r.price_upper > 2500
  end

  test "optimize range missing price" do
    assert {:error, :missing_price} = PriceOptimizer.optimize_range(%{strategy: :balanced})
  end

  test "optimize range zero price" do
    assert {:error, :invalid_price} = PriceOptimizer.optimize_range(%{current_price: 0})
  end

  test "optimize range negative price" do
    assert {:error, :invalid_price} = PriceOptimizer.optimize_range(%{current_price: -100})
  end

  test "optimize range invalid strategy" do
    assert {:error, :invalid_strategy} = PriceOptimizer.optimize_range(%{current_price: 100, strategy: :yolo})
  end

  test "capital efficiency higher for tight range" do
    {:ok, tight} = PriceOptimizer.optimize_range(%{current_price: 100.0, strategy: :tight, volatility: :low})
    {:ok, wide} = PriceOptimizer.optimize_range(%{current_price: 100.0, strategy: :wide})
    assert tight.capital_efficiency > wide.capital_efficiency
  end

  # --- IL Calculation ---

  test "calculate IL price up" do
    {:ok, r} = PriceOptimizer.calculate_il(100.0, 200.0)
    assert r.il_percentage > 0
    assert r.direction == :price_up
    assert r.price_ratio == 2.0
    assert r.lp_value_ratio < 1.0  # LP underperforms hold
  end

  test "calculate IL price down" do
    {:ok, r} = PriceOptimizer.calculate_il(100.0, 50.0)
    assert r.il_percentage > 0
    assert r.direction == :price_down
  end

  test "no IL at same price" do
    {:ok, r} = PriceOptimizer.calculate_il(100.0, 100.0)
    assert r.il_percentage == 0.0
    assert r.lp_value_ratio == 1.0
  end

  test "IL increases with larger price deviation" do
    {:ok, small} = PriceOptimizer.calculate_il(100.0, 120.0)
    {:ok, large} = PriceOptimizer.calculate_il(100.0, 200.0)
    assert large.il_percentage > small.il_percentage
  end

  test "IL symmetric for equal magnitude changes" do
    {:ok, up} = PriceOptimizer.calculate_il(100.0, 400.0)    # 4x
    {:ok, down} = PriceOptimizer.calculate_il(100.0, 25.0)   # 0.25x
    # IL is the same for inverse price ratios
    assert_in_delta up.il_percentage, down.il_percentage, 0.01
  end

  test "reject zero initial price" do
    assert {:error, :invalid_price} = PriceOptimizer.calculate_il(0, 100.0)
  end

  test "reject negative current price" do
    assert {:error, :invalid_price} = PriceOptimizer.calculate_il(100.0, -50.0)
  end

  # --- IL Scenarios ---

  test "il_scenarios returns list" do
    {:ok, results} = PriceOptimizer.il_scenarios(100.0, [50.0, 100.0, 150.0, 200.0])
    assert length(results) == 4
    assert Enum.all?(results, &Map.has_key?(&1, :target_price))
    # Zero IL at same price
    same = Enum.find(results, &(&1.target_price == 100.0))
    assert same.il_percentage == 0.0
  end
end
