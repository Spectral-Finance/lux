defmodule Lux.Trading.Hyperliquid.RiskMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Trading.Hyperliquid.RiskMonitor

  setup do
    positions = [
      %{
        coin: "ETH",
        direction: :long,
        sz: 1.0,
        entry_px: 2500.0,
        mark_px: 2600.0,
        notional: 2600.0,
        liquidation_px: 2200.0,
        unrealized_pnl: 100.0,
        roe_pct: 38.46
      },
      %{
        coin: "BTC",
        direction: :long,
        sz: 0.1,
        entry_px: 60000.0,
        mark_px: 62000.0,
        notional: 6200.0,
        liquidation_px: 54000.0,
        unrealized_pnl: 200.0,
        roe_pct: 32.26
      }
    ]
    %{positions: positions}
  end

  describe "calculate_portfolio_risk/2" do
    test "aggregates portfolio leverage and PnL", %{positions: positions} do
      equity = 5000.0
      risk = RiskMonitor.calculate_portfolio_risk(equity, positions)

      assert risk.portfolio_pnl_usd == 300.0
      assert risk.effective_leverage > 1.0
      assert risk.max_concentration_pct > 0.0
    end
  end

  describe "render_dashboard/2" do
    test "generates ASCII table output", %{positions: positions} do
      dashboard = RiskMonitor.render_dashboard(positions, 5000.0)
      assert String.contains?(dashboard, "HYPERLIQUID PERPETUAL TRADING DASHBOARD")
      assert String.contains?(dashboard, "ETH")
      assert String.contains?(dashboard, "BTC")
      assert String.contains?(dashboard, "Equity:")
    end
  end
end
