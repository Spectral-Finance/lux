defmodule Lux.Defi.CurveFinanceTest do
  use ExUnit.Case, async: true
  alias Lux.Defi.CurveFinance

  test "detects healthy vs depegged stablecoin pools and calculates gauge boost yield" do
    {:ok, healthy} =
      CurveFinance.analyze_pool_health(%{
        name: "3pool",
        reserves: %{"USDC" => 10_000_000, "USDT" => 10_000_000, "DAI" => 10_000_000},
        oracle_prices: %{"USDC" => 1.0001, "USDT" => 0.9998, "DAI" => 1.0000}
      })

    assert healthy.status == :healthy
    assert healthy.recommended_action == :provide_liquidity

    {:ok, depeg} =
      CurveFinance.analyze_pool_health(%{
        name: "3pool",
        reserves: %{"USDC" => 10_000_000, "USDT" => 10_000_000, "DAI" => 10_000_000},
        oracle_prices: %{"USDC" => 0.985, "USDT" => 1.000, "DAI" => 1.000},
        depeg_threshold_bps: 50
      })

    assert depeg.status == :critical_depeg_risk
    assert "USDC" in depeg.depegged_tokens
    assert depeg.recommended_action == :withdraw_to_safest_asset

    {:ok, yield_info} =
      CurveFinance.calculate_gauge_yield(%{
        base_fee_apr_pct: 3.0,
        crv_base_apr_pct: 4.0,
        boost_multiplier: 2.5
      })

    assert yield_info.total_net_apr_pct == 13.0
  end
end
