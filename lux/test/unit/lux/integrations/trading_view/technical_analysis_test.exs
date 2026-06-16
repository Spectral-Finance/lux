defmodule Lux.Integrations.TradingView.TechnicalAnalysisTest do
  use UnitCase, async: true

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @candles Enum.map(1..20, fn index ->
             %{
               time: "2026-06-15T#{String.pad_leading(to_string(index), 2, "0")}:00:00Z",
               open: index,
               high: index + 1,
               low: index - 1,
               close: index,
               volume: index * 100
             }
           end)

  test "normalizes TradingView-style candles" do
    assert {:ok, [first | _]} = TechnicalAnalysis.normalize_candles(@candles)
    assert first.close == 1
  end

  test "calculates moving averages and RSI" do
    values = [1, 2, 3, 4, 5]

    assert TechnicalAnalysis.sma(values, 3) == [nil, nil, 2.0, 3.0, 4.0]
    assert [nil, nil, 2.0 | _] = TechnicalAnalysis.ema(values, 3)
    assert [nil, nil, nil | _] = TechnicalAnalysis.rsi(values, 3)
  end

  test "analyzes candles with chart-ready series and alerts" do
    assert {:ok, analysis} =
             TechnicalAnalysis.analyze(@candles, sma_period: 5, ema_period: 5, rsi_period: 5)

    assert length(analysis.indicators.sma) == 20
    assert %{time: _, value: _} = List.last(analysis.indicators.sma)
    assert analysis.latest_signal in [:overbought, :oversold, :bullish, :bearish, :neutral]
    assert is_list(analysis.alerts)
  end

  test "backtests SMA crossover signals" do
    assert {:ok, backtest} = TechnicalAnalysis.backtest_sma_cross(@candles, 3, 5)
    assert backtest.strategy == "sma_cross"
    assert length(backtest.trades) == 20
    assert is_map(backtest.signal_counts)
  end
end
