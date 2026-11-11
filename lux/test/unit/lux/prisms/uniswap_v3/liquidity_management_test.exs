defmodule Lux.Prisms.UniswapV3.LiquidityManagementTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.UniswapV3.LiquidityManagementBeam
  alias Lux.Prisms.UniswapV3.FeeCollectorPrism
  alias Lux.Prisms.UniswapV3.IlProtectionPrism
  alias Lux.Prisms.UniswapV3.PositionManagerPrism
  alias Lux.Prisms.UniswapV3.RangeOptimizerPrism

  describe "PositionManagerPrism" do
    test "computes tick alignment, liquidity, and capital efficiency for in-range mint" do
      {:ok, res} =
        PositionManagerPrism.handler(
          %{
            action: "mint",
            fee_tier: 3000,
            current_price: 2500.0,
            lower_price: 2000.0,
            upper_price: 3000.0,
            amount0_desired: 1.0,
            amount1_desired: 2500.0,
            slippage_bps: 50
          },
          %{}
        )

      assert res.status == "executed"
      assert rem(res.tick_lower, 60) == 0
      assert rem(res.tick_upper, 60) == 0
      assert res.tick_lower < res.current_tick
      assert res.current_tick < res.tick_upper
      assert res.liquidity > 0
      assert res.capital_efficiency_multiplier > 4.0
    end

    test "returns error for invalid inverted range" do
      assert {:error, :invalid_price_range} =
               PositionManagerPrism.handler(
                 %{
                   action: "mint",
                   fee_tier: 500,
                   current_price: 2500.0,
                   lower_price: 3000.0,
                   upper_price: 2000.0
                 },
                 %{}
               )
    end
  end

  describe "RangeOptimizerPrism" do
    test "calculates volatility-scaled tick range and detects out-of-range position" do
      {:ok, res} =
        RangeOptimizerPrism.handler(
          %{
            current_price: 2650.0,
            twap_price: 2645.0,
            daily_volatility: 0.03,
            horizon_days: 7.0,
            confidence_sigma: 2.0,
            fee_tier: 3000,
            existing_lower_price: 2100.0,
            existing_upper_price: 2600.0
          },
          %{}
        )

      assert res.should_rebalance == true
      assert res.rebalance_reason == "out_of_range"
      assert res.optimal_lower_price < 2650.0
      assert res.optimal_upper_price > 2650.0
    end
  end

  describe "FeeCollectorPrism and IlProtectionPrism" do
    test "compounds fees when above gas threshold and evaluates concentrated IL" do
      {:ok, fees} =
        FeeCollectorPrism.handler(
          %{
            tokens_owed0: 0.04,
            tokens_owed1: 100.0,
            token0_price_usd: 2500.0,
            token1_price_usd: 1.0,
            estimated_gas_usd: 2.0,
            auto_compound: true
          },
          %{}
        )

      assert fees.total_fees_usd == 200.0
      assert fees.should_collect == true
      assert fees.action_taken == "collect_and_compound"
      assert fees.compounded_token0 > 0

      {:ok, il} =
        IlProtectionPrism.handler(
          %{
            entry_price: 2500.0,
            current_price: 2750.0,
            lower_price: 2000.0,
            upper_price: 3000.0,
            initial_amount0: 1.0,
            initial_amount1: 2500.0,
            accrued_fees_usd: fees.total_fees_usd
          },
          %{}
        )

      assert il.impermanent_loss_usd >= 0.0
      assert is_boolean(il.hedge_required)
    end
  end

  describe "LiquidityManagementBeam" do
    test "orchestrates full Uniswap V3 liquidity management workflow" do
      {:ok, result} =
        LiquidityManagementBeam.run(%{
          current_price: 2500.0,
          twap_price: 2498.0,
          daily_volatility: 0.025,
          fee_tier: 3000,
          amount0_desired: 2.0,
          amount1_desired: 5000.0
        })

      assert result.position_execution.status == "executed"
      assert result.range_optimization.optimal_tick_lower < result.range_optimization.optimal_tick_upper
      assert result.fee_collection.should_collect == true
    end
  end
end
