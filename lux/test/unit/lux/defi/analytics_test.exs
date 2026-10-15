defmodule Lux.Defi.AnalyticsTest do
  use ExUnit.Case, async: true
  alias Lux.Defi.Analytics

  test "aggregates TVL, capital efficiency, and ranks pools by risk-adjusted Sharpe ratio" do
    pools = [
      %{name: "Aave V3 USDC", chain: :base, tvl_usd: 50_000_000, volume_24h_usd: 15_000_000, apy_pct: 8.5, apy_volatility_pct: 1.5},
      %{name: "Volatile Farm", chain: :arbitrum, tvl_usd: 5_000_000, volume_24h_usd: 2_000_000, apy_pct: 14.0, apy_volatility_pct: 10.0}
    ]

    {:ok, report} = Analytics.analyze_protocols(pools, risk_free_rate_pct: 4.0)
    assert report.total_tvl_usd == 55_000_000.0
    assert report.top_risk_adjusted_pool.name == "Aave V3 USDC"
    assert report.top_risk_adjusted_pool.risk_adjusted_sharpe == 3.0
    assert report.top_risk_adjusted_pool.capital_efficiency == 0.3
  end
end
