defmodule Lux.Integrations.Curve.PoolManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Curve.PoolManager

  test "computes slippage min_dy and selects optimal stablecoin pool" do
    assert {:ok, 998.5} = PoolManager.calculate_min_dy(1000.0, 15)

    pools = [
      %{name: "3pool", tvl_usd: 150_000_000.0, peg_deviation_bps: 5, base_apy: 2.1, crv_apy: 3.4},
      %{name: "frax_usdc", tvl_usd: 45_000_000.0, peg_deviation_bps: 8, base_apy: 3.2, crv_apy: 4.8}
    ]

    assert {:ok, %{name: "frax_usdc"}} = PoolManager.select_optimal_pool(pools)
    assert {:ok, 2.5} = PoolManager.calculate_gauge_boost(1000.0, 10_000.0, 500.0, 1000.0)
  end
end
