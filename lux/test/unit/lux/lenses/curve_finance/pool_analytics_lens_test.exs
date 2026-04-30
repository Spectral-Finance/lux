defmodule Lux.Lenses.CurveFinance.PoolAnalyticsLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.CurveFinance.PoolAnalyticsLens

  describe "run/1" do
    test "analyzes single pool by address" do
      params = %{pool_address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7"}
      assert {:ok, result} = PoolAnalyticsLens.run(params)
      assert result.tvl > 0
      assert result.apy > 0
      assert result.volume_24h > 0
      assert length(result.coins) > 0
    end

    test "fetches pool list by chain" do
      params = %{chain: "ethereum", limit: 5}
      assert {:ok, result} = PoolAnalyticsLens.run(params)
      assert result.total > 0
      assert length(result.pools) <= 5
    end

    test "includes history when requested" do
      params = %{pool_address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7", include_history: true}
      assert {:ok, result} = PoolAnalyticsLens.run(params)
      assert result.coins == ["DAI", "USDC", "USDT", "TUSD"]
    end
  end

  describe "analyze_single_pool/2" do
    test "returns detailed pool analysis" do
      address = "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7"
      assert {:ok, result} = PoolAnalyticsLens.analyze_single_pool(address, %{include_history: false})
      assert result.tvl_usd > 0
      assert result.base_apy > 0
      assert result.crv_apy > 0
      assert result.gauge_address != nil
    end
  end

  describe "fetch_pool_list/2" do
    test "returns filtered pools by TVL" do
      assert {:ok, result} = PoolAnalyticsLens.fetch_pool_list("ethereum", %{limit: 10, min_tvl: 500_000_000})
      assert result.total > 0
      Enum.each(result.pools, fn pool ->
        assert pool.tvl_usd >= 500_000_000
      end)
    end

    test "sorts pools by TVL descending" do
      assert {:ok, result} = PoolAnalyticsLens.fetch_pool_list("ethereum", %{limit: 10})
      tvls = Enum.map(result.pools, & &1.tvl_usd)
      assert tvls == Enum.sort(tvls, :desc)
    end
  end
end
