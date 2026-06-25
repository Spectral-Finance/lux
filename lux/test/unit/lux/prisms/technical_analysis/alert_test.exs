defmodule Lux.Unit.Prisms.TechnicalAnalysis.AlertTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.AlertManager

  describe "handler/2 - alert triggering" do
    test "triggers RSI overbought alert" do
      input = %{
        indicators: %{rsi: 75.0, macd_histogram: 0.1, bb_pct_b: 0.5},
        alerts: [%{type: "rsi_overbought", threshold: 70}]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      assert length(result.alerts_triggered) == 1
      assert result.overall_sentiment in ["bullish", "bearish", "neutral"]
      assert is_number(result.confidence)
    end

    test "triggers RSI oversold alert" do
      input = %{
        indicators: %{rsi: 25.0, macd_histogram: -0.1, bb_pct_b: 0.1},
        alerts: [%{type: "rsi_oversold", threshold: 30}]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      assert length(result.alerts_triggered) == 1
    end

    test "no alerts triggered when conditions not met" do
      input = %{
        indicators: %{rsi: 50.0, macd_histogram: 0.0, bb_pct_b: 0.5},
        alerts: [%{type: "rsi_overbought", threshold: 70}]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      assert length(result.alerts_triggered) == 0
      assert result.signals == []
    end

    test "multiple alerts can trigger simultaneously" do
      input = %{
        indicators: %{rsi: 75.0, macd_histogram: 0.5, bb_pct_b: 1.2},
        alerts: [
          %{type: "rsi_overbought", threshold: 70},
          %{type: "macd_bullish_cross", threshold: 0},
          %{type: "price_above_bb", threshold: 1.0}
        ]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      assert length(result.alerts_triggered) == 3
    end

    test "sensitivity affects alert triggering" do
      input = %{
        indicators: %{rsi: 68.0},
        alerts: [%{type: "rsi_overbought", threshold: 70}],
        sensitivity: 0.5
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      # With sensitivity 0.5, effective threshold becomes 140, so won't trigger
      assert length(result.alerts_triggered) == 0
    end
  end

  describe "handler/2 - signal generation" do
    test "generates buy signals from oversold conditions" do
      input = %{
        indicators: %{rsi: 25.0},
        alerts: [%{type: "rsi_oversold", threshold: 30}]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      buy_signals = Enum.count(result.signals, &(&1.type == "buy"))
      assert buy_signals > 0
    end

    test "generates sell signals from overbought conditions" do
      input = %{
        indicators: %{rsi: 75.0},
        alerts: [%{type: "rsi_overbought", threshold: 70}]
      }

      assert {:ok, result} = AlertManager.handler(input, nil)
      sell_signals = Enum.count(result.signals, &(&1.type == "sell"))
      assert sell_signals > 0
    end
  end
end
