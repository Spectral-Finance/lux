defmodule Lux.Unit.Prisms.TechnicalAnalysis.MultiTimeframeTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.MultiTimeframe

  describe "handler/2 - multi-timeframe analysis" do
    test "identifies bullish confluence across timeframes" do
      input = %{
        timeframes: %{
          "1D" => %{rsi: 60, trend: "uptrend", macd: "bullish"},
          "4H" => %{rsi: 55, trend: "uptrend", macd: "bullish"},
          "1H" => %{rsi: 45, trend: "neutral", macd: "none"}
        }
      }

      assert {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.dominant_trend == "bullish"
      assert result.confluence in ["strong", "moderate", "weak", "divergent"]
      assert is_map(result.timeframe_signals)
    end

    test "identifies bearish confluence" do
      input = %{
        timeframes: %{
          "1D" => %{rsi: 70, trend: "downtrend", macd: "bearish"},
          "4H" => %{rsi: 65, trend: "downtrend", macd: "bearish"}
        }
      }

      assert {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.dominant_trend == "bearish"
    end

    test "detects divergent signals" do
      input = %{
        timeframes: %{
          "1D" => %{rsi: 30, trend: "uptrend", macd: "bullish"},
          "1H" => %{rsi: 70, trend: "downtrend", macd: "bearish"}
        }
      }

      assert {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.confluence in ["weak", "divergent"]
      assert result.recommendation in ["hold", "cautious_buy", "cautious_sell"]
    end

    test "returns hold for all neutral" do
      input = %{
        timeframes: %{
          "1D" => %{trend: "neutral", macd: "none"},
          "4H" => %{trend: "neutral", macd: "none"},
          "1H" => %{trend: "neutral", macd: "none"}
        }
      }

      assert {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.dominant_trend == "neutral"
      assert result.recommendation == "hold"
    end

    test "generates strong_buy for strong bullish confluence" do
      input = %{
        timeframes: %{
          "1M" => %{rsi: 40, trend: "uptrend", macd: "bullish"},
          "1D" => %{rsi: 35, trend: "uptrend", macd: "bullish"},
          "4H" => %{rsi: 45, trend: "uptrend", macd: "bullish"},
          "1H" => %{rsi: 50, trend: "uptrend", macd: "bullish"}
        }
      }

      assert {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.recommendation == "strong_buy"
      assert result.confidence >= 0.8
    end
  end
end
