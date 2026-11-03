defmodule Lux.Defi.PancakeSwap.FarmingEngineTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.FarmingEngine

  describe "calculate_pool_apy/7" do
    test "computes fee apr, farming apr, total apr, and APY" do
      # TVL: 1,000,000, Daily Vol: 200,000, Fee: 0.0025 (25 bps)
      # Daily fee = 500, annual fee = 182,500, fee apr = 18.25%
      # cake_per_sec = 1.0, alloc = 100 / 1000 = 0.1 cake/sec
      # annual cake = 3,153,600, price = 2.0 -> 6,307,200 USD -> 630.72%
      result =
        FarmingEngine.calculate_pool_apy(
          1_000_000.0,
          200_000.0,
          0.0025,
          1.0,
          100,
          1000,
          2.0
        )

      assert result.fee_apr_pct == 18.25
      assert result.farming_apr_pct == 630.72
      assert result.total_apr_pct == 648.97
      assert result.compounded_apy_pct > result.total_apr_pct
    end

    test "handles zero TVL safely" do
      result = FarmingEngine.calculate_pool_apy(0.0, 100.0, 0.0025, 1.0, 100, 1000, 2.0)
      assert result.total_apr_pct == 0.0
      assert result.compounded_apy_pct == 0.0
    end
  end

  describe "harvest_profitable?/3" do
    test "returns true when reward value exceeds 5x gas cost" do
      # 5.0 CAKE @ $2.50 = $12.50. Gas = $0.50 (threshold = $2.50)
      assert {:ok, true, 12.5} = FarmingEngine.harvest_profitable?(5.0, 2.50, 0.50)
    end

    test "returns false when reward is smaller than 5x gas cost" do
      # 0.5 CAKE @ $2.00 = $1.00. Gas = $0.50 (threshold = $2.50)
      assert {:ok, false, 1.0} = FarmingEngine.harvest_profitable?(0.5, 2.00, 0.50)
    end
  end
end
