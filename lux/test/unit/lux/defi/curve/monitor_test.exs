defmodule Lux.Defi.Curve.MonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.Monitor

  describe "evaluate_pool_health/2" do
    test "reports healthy score for balanced pool" do
      report = Monitor.evaluate_pool_health([1000, 1000, 1000])
      assert report.score == 100
      assert report.status == :healthy
      assert report.alerts == []
    end

    test "reports depeg risk for severe skew" do
      report = Monitor.evaluate_pool_health([1000, 50, 1000])
      assert report.score <= 50
      assert report.status == :depeg_risk
      assert length(report.alerts) > 0
    end
  end

  describe "render_dashboard/1" do
    test "generates ASCII table output" do
      data = [
        %{
          pool_id: "3pool",
          name: "Curve 3pool",
          virtual_price: 1.025,
          value_usd: 25000,
          boost: 2.2,
          total_apy: 8.4,
          status: :healthy,
          health_score: 95
        }
      ]

      output = Monitor.render_dashboard(data)
      assert String.contains?(output, "CURVE STABLECOIN MANAGEMENT DASHBOARD")
      assert String.contains?(output, "3pool")
      assert String.contains?(output, "Curve 3pool")
      assert String.contains?(output, "2.2x")
    end
  end
end
