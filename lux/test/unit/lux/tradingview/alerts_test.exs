defmodule Lux.TradingView.AlertsTest do
  use UnitCase, async: true

  alias Lux.TradingView.Alerts

  @test_snapshot %{
    symbol: "ETHUSDT",
    current_price: 3500.0,
    rsi: 75.0,
    macd: %{histogram: 1.5},
    bollinger_bands: %{upper: 3450.0, lower: 3100.0, middle: 3275.0}
  }

  describe "evaluate_alerts/2" do
    test "triggers price_above alert when threshold is exceeded" do
      rules = [
        %{
          id: "rule-1",
          symbol: "ETHUSDT",
          condition: :price_above,
          threshold: 3400.0,
          cooldown_sec: 60
        }
      ]

      {:ok, result} = Alerts.evaluate_alerts(rules, @test_snapshot)
      assert result.active_count == 1
      [alert] = result.triggered_alerts
      assert alert.rule_id == "rule-1"
      assert alert.price == 3500.0
    end

    test "triggers rsi_overbought alert" do
      rules = [
        %{
          id: "rule-rsi",
          condition: :rsi_overbought,
          threshold: 70.0,
          cooldown_sec: 60
        }
      ]

      {:ok, result} = Alerts.evaluate_alerts(rules, @test_snapshot)
      assert result.active_count == 1
      assert hd(result.triggered_alerts).condition == :rsi_overbought
    end

    test "triggers bb_breakout_upper alert" do
      rules = [
        %{
          id: "rule-bb",
          condition: :bb_breakout_upper,
          cooldown_sec: 60
        }
      ]

      {:ok, result} = Alerts.evaluate_alerts(rules, @test_snapshot)
      assert result.active_count == 1
      assert hd(result.triggered_alerts).condition == :bb_breakout_upper
    end

    test "respects cooldown period for recently triggered alerts" do
      now = System.system_time(:second)

      rules = [
        %{
          id: "rule-cooldown",
          condition: :price_above,
          threshold: 3000.0,
          cooldown_sec: 300,
          last_triggered: now - 30
        }
      ]

      {:ok, result} = Alerts.evaluate_alerts(rules, @test_snapshot)
      assert result.active_count == 0
      assert result.triggered_alerts == []
    end
  end
end
