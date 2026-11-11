defmodule Lux.Prisms.TradingView.TechnicalAnalysisTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.TradingView.TechnicalAnalysisPrism, as: TA

  describe "technical indicators and signal generation" do
    test "computes SMA, EMA, RSI, Bollinger Bands, and backtest metrics" do
      closes = Enum.map(1..30, fn i -> 100.0 + i * 1.5 end)

      assert {:ok, sma_10} = TA.sma(closes, 10)
      assert sma_10 > 130.0

      assert {:ok, rsi_14} = TA.rsi(closes, 14)
      assert rsi_14 == 100.0

      assert {:ok, bb} = TA.bollinger_bands(closes, 20, 2.0)
      assert bb.upper > bb.middle and bb.middle > bb.lower

      assert {:ok, bt} = TA.backtest(closes, 10_000.0)
      assert bt.final_equity > 10_000.0
      assert bt.win_rate == 1.0
    end
  end
end
