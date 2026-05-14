defmodule Lux.Prisms.TradingView.AnalyzeChartTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.AnalyzeChart

  test "returns chart analysis" do
    bars = for i <- 1..25, do: %{time: i, open: i, high: i + 1, low: i - 1, close: i, volume: 1}

    assert {:ok, result} =
             AnalyzeChart.handler(%{bars: bars, indicators: %{sma: [3], ema: [], rsi: []}}, nil)

    assert result.summary.bars == 25
    assert result.chart.latest.close == 25.0
  end
end
