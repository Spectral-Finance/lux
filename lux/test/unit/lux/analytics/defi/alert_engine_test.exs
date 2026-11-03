defmodule Lux.Analytics.Defi.AlertEngineTest do
  use UnitCase, async: true

  alias Lux.Analytics.Defi.AlertEngine

  describe "check_tvl_drawdown/3" do
    test "triggers warning alert on 12% drawdown" do
      assert {:ok, alert} = AlertEngine.check_tvl_drawdown("Aave", -12.5, -10.0)
      assert alert.type == :tvl_shock
      assert alert.severity == :warning
      assert alert.metric_value == -12.5
    end

    test "triggers critical alert on severe 30% crash" do
      assert {:ok, alert} = AlertEngine.check_tvl_drawdown("ProtocolX", -30.0, -10.0)
      assert alert.severity == :critical
    end

    test "returns :no_alert when change is healthy" do
      assert :no_alert == AlertEngine.check_tvl_drawdown("Uniswap", 5.0, -10.0)
      assert :no_alert == AlertEngine.check_tvl_drawdown("Curve", -4.0, -10.0)
    end
  end

  describe "check_depeg/3" do
    test "triggers warning alert on 1.5% depeg" do
      assert {:ok, alert} = AlertEngine.check_depeg("USDT", 0.985, 1.0)
      assert alert.type == :depeg_risk
      assert alert.severity == :warning
      assert alert.metric_value == 1.5
    end

    test "triggers critical alert on 6% depeg" do
      assert {:ok, alert} = AlertEngine.check_depeg("UST", 0.94, 1.0)
      assert alert.severity == :critical
    end

    test "returns :no_alert when price is pegged" do
      assert :no_alert == AlertEngine.check_depeg("USDC", 0.999, 1.0)
    end
  end

  describe "check_yield_anomaly/4" do
    test "triggers warning on abnormal 250% APY" do
      assert {:ok, alert} = AlertEngine.check_yield_anomaly("FarmY", 250.0, 200.0, 0.0)
      assert alert.type == :yield_anomaly
      assert alert.severity == :warning
    end

    test "triggers info on zero yield" do
      assert {:ok, alert} = AlertEngine.check_yield_anomaly("DeadPool", 0.0, 200.0, 0.0)
      assert alert.severity == :info
    end

    test "returns :no_alert on normal yield" do
      assert :no_alert == AlertEngine.check_yield_anomaly("SafePool", 12.5, 200.0, 0.0)
    end
  end
end
