defmodule Lux.Defi.UniswapV3.MonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.Monitor

  describe "check_health/6" do
    test "reports healthy score when in range with minimal IL" do
      pos = %{token_id: "pos_1", tick_lower: 100, tick_upper: 300}
      report = Monitor.check_health(pos, 200, 2000.0, 2005.0, 1950.0, 2050.0)

      assert report.in_range? == true
      assert report.health_score >= 80
      assert report.status == :healthy
      assert report.alerts == []
    end

    test "reports warning or critical when out of range" do
      pos = %{token_id: "pos_2", tick_lower: 100, tick_upper: 300}
      report = Monitor.check_health(pos, 50, 2000.0, 1800.0, 1900.0, 2100.0)

      assert report.in_range? == false
      assert report.health_score < 60
      assert length(report.alerts) > 0
    end
  end

  describe "render_dashboard/1" do
    test "generates ASCII table output" do
      data = [
        %{
          token_id: "pos_991",
          pair: "WETH/USDC",
          fee: 3000,
          in_range?: true,
          health_score: 95,
          il_pct: 0.4,
          value_usd: 12500,
          apr_pct: 34.5,
          action: "HOLD"
        }
      ]

      output = Monitor.render_dashboard(data)
      assert String.contains?(output, "UNISWAP V3 LIQUIDITY MANAGEMENT DASHBOARD")
      assert String.contains?(output, "pos_991")
      assert String.contains?(output, "WETH/USDC")
      assert String.contains?(output, "IN RANGE")
    end
  end
end
