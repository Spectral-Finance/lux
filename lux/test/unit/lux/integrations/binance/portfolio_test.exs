defmodule Lux.Integrations.Binance.PortfolioTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.Portfolio

  describe "aggregate_spot_balances/2" do
    test "filters zero balances and computes USDT total value" do
      balances = [
        %{"asset" => "BTC", "free" => "0.5", "locked" => "0.1"},
        %{"asset" => "USDT", "free" => "1500.0", "locked" => "500.0"},
        %{"asset" => "XRP", "free" => "0.0", "locked" => "0.0"}
      ]

      prices = %{"BTCUSDT" => 60_000.0}

      result = Portfolio.aggregate_spot_balances(balances, prices)

      # 0.6 BTC @ 60,000 = 36,000 + 2,000 USDT = 38,000
      assert result.total_spot_usdt == 38_000.0
      assert length(result.balances) == 2
    end
  end

  describe "evaluate_futures_risk/3" do
    test "evaluates margin ratio and classifies health" do
      # MM = 500, MB = 10,000 -> ratio = 5% (safe)
      safe = Portfolio.evaluate_futures_risk(500.0, 10_000.0, 10_000.0)
      assert safe.margin_ratio_pct == 5.0
      assert safe.health_status == :safe

      # MM = 7,000, MB = 10,000 -> ratio = 70% (warning)
      warning = Portfolio.evaluate_futures_risk(7_000.0, 10_000.0, 10_000.0)
      assert warning.health_status == :warning

      # MM = 9,000, MB = 10,000 -> ratio = 90% (critical)
      critical = Portfolio.evaluate_futures_risk(9_000.0, 10_000.0, 10_000.0)
      assert critical.health_status == :critical
      assert critical.liquidation_risk == 0.90
    end
  end
end
