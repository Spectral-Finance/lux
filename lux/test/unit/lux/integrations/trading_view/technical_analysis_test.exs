defmodule Lux.Integrations.TradingView.TechnicalAnalysisTest do
  use UnitCase, async: true

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @bars for i <- 1..40 do
    %{time: i, open: 100 + i, high: 102 + i, low: 99 + i, close: 100 + i, volume: 1_000 + i}
  end

  test "normalizes chart rows and calculates indicators" do
    result =
      TechnicalAnalysis.analyze(@bars,
        symbol: "ETHUSDT",
        timeframe: "1h",
        indicators: %{
          sma: [3],
          ema: [3],
          rsi: [3],
          macd: %{fast: 3, slow: 6, signal: 3},
          bollinger: %{period: 3, deviations: 2.0}
        }
      )

    assert result.chart.symbol == "ETHUSDT"
    assert result.chart.latest.close == 140.0
    assert [%{value: 102.0} | _] = result.indicators.sma[3]
    assert [%{value: 100.0} | _] = result.indicators.ema[3]
    assert result.signals.trend in [:bullish, :neutral]
  end

  test "evaluates alert rules including crosses" do
    bars = [
      %{time: 1, open: 10, high: 11, low: 9, close: 10, volume: 1},
      %{time: 2, open: 10, high: 13, low: 9, close: 12, volume: 1}
    ]

    indicators =
      TechnicalAnalysis.calculate_indicators(bars, %{
        sma: [1],
        ema: [],
        rsi: [],
        macd: %{fast: 1, slow: 2, signal: 1},
        bollinger: %{period: 1, deviations: 2}
      })

    [alert] =
      TechnicalAnalysis.evaluate_alerts(bars, indicators, [
        %{
          id: "breakout",
          field: "close",
          operator: "crosses_above",
          value: 11,
          severity: "warning"
        }
      ])

    assert alert.triggered == true
    assert alert.severity == :warning
  end

  test "backtests moving average crossover strategy" do
    result =
      TechnicalAnalysis.backtest_strategy(@bars,
        fast_period: 2,
        slow_period: 4,
        initial_cash: 1_000
      )

    assert result.strategy == :sma_crossover
    assert result.trade_count >= 1
    assert result.final_equity > 1_000
    assert [%{side: :buy}] = result.trades
  end

  test "summarizes multiple timeframes" do
    result =
      TechnicalAnalysis.multi_timeframe_summary(%{"1h" => @bars, "1d" => Enum.take(@bars, 20)})

    assert result["1h"].bars == 40
    assert result["1d"].latest_close == 120.0
  end
end
