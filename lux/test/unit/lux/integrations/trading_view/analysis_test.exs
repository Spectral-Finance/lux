defmodule Lux.Integrations.TradingView.AnalysisTest do
  use UnitCase, async: true

  alias Lux.Integrations.TradingView.Analysis

  describe "moving averages" do
    test "normalizes bars and calculates SMA/EMA values" do
      bars = Enum.reverse(uptrend_bars())

      assert Enum.map(Analysis.normalize_bars(bars), & &1.close) == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

      sma = Analysis.sma(bars, 3)
      ema = Analysis.ema(bars, 3)

      assert length(sma) == 4
      assert List.last(sma).value == 5.0
      assert length(ema) == 6
      assert hd(ema).value == 1.0
      assert List.last(ema).value > 5.0
    end
  end

  describe "indicators" do
    test "calculates RSI, MACD, and Bollinger bands" do
      bars = uptrend_bars()

      rsi = Analysis.rsi(bars, 3)
      macd = Analysis.macd(bars, %{fast: 2, slow: 3, signal: 2})
      bands = Analysis.bollinger_bands(bars, %{period: 3, multiplier: 2})

      assert List.last(rsi).value == 100.0
      assert length(macd) == 6
      assert %{histogram: _, signal: _, params: %{fast: 2, slow: 3, signal: 2}} = List.last(macd)
      assert length(bands) == 4

      latest_bands = List.last(bands)
      assert latest_bands.upper > latest_bands.middle
      assert latest_bands.middle > latest_bands.lower
    end
  end

  describe "signals and alerts" do
    test "generates bullish signals and evaluates alert rules" do
      bars = uptrend_bars()

      signal =
        Analysis.generate_signals(bars, %{
          symbol: "LUXUSDT",
          short_sma: 2,
          long_sma: 4,
          rsi_period: 10
        })

      assert signal.symbol == "LUXUSDT"
      assert signal.latest_close == 6.0
      assert signal.direction == :bullish
      assert signal.confidence > 0

      alerts =
        Analysis.evaluate_alerts(
          bars,
          [
            %{source: :close, operator: :gt, threshold: 5},
            %{source: :rsi, operator: "gte", threshold: 80},
            %{source: :volume, operator: :lt, threshold: 10}
          ],
          %{rsi: 82}
        )

      assert Enum.map(alerts, & &1.source) == [:close, :rsi]
      assert Enum.all?(alerts, &(&1.triggered_at == "2026-05-13T00:05:00Z"))
    end

    test "summarizes multiple timeframes into a consensus" do
      summary =
        Analysis.multi_timeframe_summary(
          %{
            "1m" => uptrend_bars(),
            "5m" => uptrend_bars()
          },
          %{short_sma: 2, long_sma: 4, rsi_period: 10}
        )

      assert summary.consensus == :bullish
      assert summary.bullish_count == 2
      assert Map.has_key?(summary.timeframes, "1m")
    end
  end

  describe "backtests" do
    test "runs a simple SMA crossover strategy" do
      result = Analysis.backtest_crossover(crossover_bars(), %{short: 2, long: 3, fee_bps: 10})

      assert result.strategy == :sma_crossover
      assert result.short == 2
      assert result.long == 3
      assert result.trade_count >= 1
      assert is_float(result.total_return)
      assert [%{entry_time: _, exit_time: _, return: _} | _] = result.trades
    end
  end

  defp uptrend_bars do
    for index <- 0..5 do
      close = index + 1

      %{
        time: "2026-05-13T00:0#{index}:00Z",
        open: close - 0.1,
        high: close + 0.2,
        low: close - 0.2,
        close: close,
        volume: 10 + index
      }
    end
  end

  defp crossover_bars do
    [5, 4, 3, 4, 5, 6, 5, 4, 3]
    |> Enum.with_index()
    |> Enum.map(fn {close, index} ->
      %{
        time: "2026-05-13T00:#{String.pad_leading(to_string(index), 2, "0")}:00Z",
        open: close,
        high: close + 0.5,
        low: close - 0.5,
        close: close,
        volume: 100 + index
      }
    end)
  end
end
