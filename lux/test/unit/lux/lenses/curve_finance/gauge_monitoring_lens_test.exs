defmodule Lux.Lenses.CurveFinance.GaugeMonitoringLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.CurveFinance.GaugeMonitoringLens

  describe "run/1" do
    test "monitors single gauge" do
      params = %{gauge_address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366"}
      assert {:ok, result} = GaugeMonitoringLens.run(params)
      assert result.gauge.address != nil
      assert result.emissions.crv_per_day > 0
      assert result.health_score.overall > 0
    end

    test "monitors all active gauges" do
      params = %{active_only: true}
      assert {:ok, result} = GaugeMonitoringLens.run(params)
      assert result.total > 0
      Enum.each(result.gauges, fn g ->
        refute g.is_killed
      end)
    end

    test "includes voting incentives when requested" do
      params = %{gauge_address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366", include_voting: true}
      assert {:ok, result} = GaugeMonitoringLens.run(params)
      assert result.voting_incentives.votes > 0
    end
  end
end
