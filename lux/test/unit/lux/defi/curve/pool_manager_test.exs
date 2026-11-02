defmodule Lux.Defi.Curve.PoolManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.PoolManager

  @unit 1_000_000_000_000_000_000

  describe "get_pool/1 and list_pools/0" do
    test "retrieves 3pool by id" do
      assert {:ok, pool} = PoolManager.get_pool("3pool")
      assert pool.name == "Curve 3pool (DAI/USDC/USDT)"
      assert pool.amp == 2000
    end

    test "lists pre-configured pools" do
      pools = PoolManager.list_pools()
      assert length(pools) >= 2
    end
  end

  describe "calculate_virtual_price/3" do
    test "calculates virtual price >= 1.0" do
      balances = [1000 * @unit, 1000 * @unit, 1000 * @unit]
      vp = PoolManager.calculate_virtual_price(balances, 2000, 3000 * @unit)
      assert_in_delta vp, 1.0, 0.001
    end
  end

  describe "analyze_balances/2" do
    test "detects balanced pool" do
      analysis = PoolManager.analyze_balances([1000, 1000, 1000], 0.05)
      assert analysis.imbalanced? == false
      assert analysis.max_deviation_pct < 5.0
    end

    test "detects imbalanced pool and identifies scarce coin" do
      # Coin 1 (index 1) has only 200 vs 1000 and 1000
      analysis = PoolManager.analyze_balances([1000, 200, 1000], 0.05)
      assert analysis.imbalanced? == true
      assert analysis.underrepresented_index == 1
    end
  end
end
