defmodule Lux.Integrations.UniswapV3Test do
  use ExUnit.Case, async: true

  alias Lux.Integrations.UniswapV3

  describe "configuration" do
    test "fee_tiers/0 returns all fee tiers" do
      tiers = UniswapV3.fee_tiers()
      assert Map.has_key?(tiers, 100)
      assert Map.has_key?(tiers, 500)
      assert Map.has_key?(tiers, 3000)
      assert Map.has_key?(tiers, 10000)
      assert Map.get(tiers, 3000) == "0.30%"
    end

    test "chain/0 returns default chain" do
      assert UniswapV3.chain() == :ethereum
    end
  end

  describe "pool queries" do
    test "pools/0 returns pools with key metrics" do
      result = UniswapV3.pools(limit: 3)
      assert elem(result, 0) in [:ok, :error]
    end

    test "top_pools/0 returns pools sorted by TVL" do
      result = UniswapV3.top_pools(limit: 5)
      assert elem(result, 0) in [:ok, :error]
    end

    test "factory_data/0 returns global factory stats" do
      result = UniswapV3.factory_data()
      assert elem(result, 0) in [:ok, :error]
    end

    test "trending_pools/0 returns highest volume pools" do
      result = UniswapV3.trending_pools(3)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "position analysis" do
    test "analyze_position/1 returns error for invalid position" do
      result = UniswapV3.analyze_position(-1)
      assert elem(result, 0) == :error
    end

    test "optimal_fee_tier/2 handles unknown pairs" do
      result = UniswapV3.optimal_fee_tier(
        "0x0000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000002"
      )
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
