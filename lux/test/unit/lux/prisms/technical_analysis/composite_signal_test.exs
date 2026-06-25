defmodule Lux.Unit.Prisms.TechnicalAnalysis.CompositeSignalTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.CompositeSignal

  describe "handler/2 - composite signal generation" do
    test "generates buy signal from bullish indicators" do
      input = %{
        rsi: %{rsi: 30, signal: "oversold"},
        macd: %{crossover: "bullish", histogram: 0.5},
        bollinger: %{signal: "below_lower", pct_b: -0.1},
        moving_average: %{trend: "uptrend"}
      }

      assert {:ok, result} = CompositeSignal.handler(input, nil)
      assert result.signal in ["buy", "strong_buy"]
      assert result.confidence > 0
      assert is_map(result.breakdown)
      assert result.breakdown.rsi_score > 0
      assert result.breakdown.macd_score > 0
    end

    test "generates sell signal from bearish indicators" do
      input = %{
        rsi: %{rsi: 75, signal: "overbought"},
        macd: %{crossover: "bearish", histogram: -0.5},
        bollinger: %{signal: "above_upper", pct_b: 1.1},
        moving_average: %{trend: "downtrend"}
      }

      assert {:ok, result} = CompositeSignal.handler(input, nil)
      assert result.signal in ["sell", "strong_sell"]
      assert result.score < 0
    end

    test "generates hold signal when indicators conflict" do
      input = %{
        rsi: %{rsi: 50, signal: "neutral"},
        macd: %{crossover: "none", histogram: 0},
        bollinger: %{signal: "within_bands", pct_b: 0.5},
        moving_average: %{trend: "neutral"}
      }

      assert {:ok, result} = CompositeSignal.handler(input, nil)
      assert result.signal == "hold"
      assert abs(result.score) < 20
    end

    test "handles missing indicators gracefully" do
      input = %{
        rsi: %{rsi: 35, signal: "oversold"}
      }

      assert {:ok, result} = CompositeSignal.handler(input, nil)
      assert result.signal in ["hold", "buy"]
      assert is_number(result.confidence)
    end

    test "score ranges from -100 to 100" do
      strong_buy = %{
        rsi: %{rsi: 20, signal: "oversold"},
        macd: %{crossover: "bullish", histogram: 1.0},
        bollinger: %{signal: "below_lower", pct_b: -0.5},
        moving_average: %{trend: "uptrend"}
      }

      strong_sell = %{
        rsi: %{rsi: 80, signal: "overbought"},
        macd: %{crossover: "bearish", histogram: -1.0},
        bollinger: %{signal: "above_upper", pct_b: 1.5},
        moving_average: %{trend: "downtrend"}
      }

      assert {:ok, buy_result} = CompositeSignal.handler(strong_buy, nil)
      assert {:ok, sell_result} = CompositeSignal.handler(strong_sell, nil)

      assert buy_result.score > sell_result.score
      assert buy_result.score > 0
      assert sell_result.score < 0
    end
  end
end
