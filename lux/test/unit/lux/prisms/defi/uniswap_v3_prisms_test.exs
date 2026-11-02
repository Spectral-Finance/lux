defmodule Lux.Prisms.Defi.UniswapV3PrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Defi.UniswapV3.{
    CreatePositionPrism,
    OptimizeRangePrism,
    CheckPositionHealthPrism,
    CollectAndReinvestPrism,
    RebalancePositionPrism
  }

  @weth "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

  describe "CreatePositionPrism" do
    test "creates concentrated liquidity position" do
      input = %{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        tick_lower: -600,
        tick_upper: 600,
        liquidity: 100_000
      }

      assert {:ok, res} = CreatePositionPrism.run(input)
      assert is_binary(res.token_id)
      assert is_binary(res.pool_address)
      assert res.tick_lower == -600
      assert res.tick_upper == 600
    end
  end

  describe "OptimizeRangePrism" do
    test "calculates optimal range parameters" do
      input = %{
        current_tick: 200_000,
        fee: 3000,
        strategy: "moderate"
      }

      assert {:ok, res} = OptimizeRangePrism.run(input)
      assert res.tick_lower < 200_000
      assert res.tick_upper > 200_000
      assert res.efficiency > 1.0
    end
  end

  describe "CheckPositionHealthPrism" do
    test "evaluates position health metrics" do
      input = %{
        position: %{token_id: "pos_123", tick_lower: 100, tick_upper: 500},
        current_tick: 300,
        entry_price: 2500.0,
        current_price: 2510.0,
        price_lower: 2400.0,
        price_upper: 2600.0
      }

      assert {:ok, res} = CheckPositionHealthPrism.run(input)
      assert res.token_id == "pos_123"
      assert res.in_range == true
      assert res.health_score >= 80
      assert res.status == "healthy"
    end
  end

  describe "CollectAndReinvestPrism" do
    test "plans fee re-investment" do
      input = %{
        collected0: 500,
        collected1: 500,
        target_ratio: 1.0
      }

      assert {:ok, res} = CollectAndReinvestPrism.run(input)
      assert res.reinvest0 == 500
      assert res.reinvest1 == 500
      assert res.swap_required == false
    end
  end

  describe "RebalancePositionPrism" do
    test "plans rebalance when out of range" do
      input = %{
        position: %{token_id: "pos_test", tick_lower: -600, tick_upper: 600, fee: 3000},
        current_tick: 1000,
        strategy: "moderate"
      }

      assert {:ok, res} = RebalancePositionPrism.run(input)
      assert res.action == "rebalance"
      assert res.viable == true
      assert res.new_tick_lower < 1000
      assert res.new_tick_upper > 1000
    end
  end
end
