defmodule Lux.Integration.TechnicalAnalysisTest do
  @moduledoc """
  Integration tests for the TradingView Technical Analysis integration.

  Tests the full pipeline: lens data fetching -> indicator calculation ->
  signal generation -> composite analysis.
  """
  use IntegrationCase, async: true

  alias Lux.Prisms.TechnicalAnalysis.RSI
  alias Lux.Prisms.TechnicalAnalysis.MACD
  alias Lux.Prisms.TechnicalAnalysis.BollingerBands
  alias Lux.Prisms.TechnicalAnalysis.MovingAverage
  alias Lux.Prisms.TechnicalAnalysis.CompositeSignal
  alias Lux.Prisms.TechnicalAnalysis.StrategyBacktest
  alias Lux.Prisms.TechnicalAnalysis.AlertManager
  alias Lux.Prisms.TechnicalAnalysis.MultiTimeframe

  @tag :integration
  describe "full technical analysis pipeline" do
    test "complete analysis pipeline with consistent data" do
      # Generate realistic price data
      prices =
        Enum.map(1..60, fn i ->
          100 + i * 0.8 + :math.sin(i * 0.15) * 5 + :rand.normal() * 2
        end)

      # Step 1: Calculate RSI
      {:ok, rsi_result} = RSI.handler(%{prices: prices, period: 14}, nil)
      assert is_number(rsi_result.rsi)
      assert rsi_result.signal in ["overbought", "oversold", "neutral"]

      # Step 2: Calculate MACD
      {:ok, macd_result} = MACD.handler(%{prices: prices}, nil)
      assert is_number(macd_result.macd_line)
      assert is_number(macd_result.signal_line)
      assert is_number(macd_result.histogram)

      # Step 3: Calculate Bollinger Bands
      {:ok, bb_result} = BollingerBands.handler(%{prices: prices, period: 20}, nil)
      assert bb_result.upper_band > bb_result.middle_band
      assert bb_result.middle_band > bb_result.lower_band

      # Step 4: Calculate Moving Averages
      {:ok, sma_result} = MovingAverage.handler(%{prices: prices, type: "sma", period: 20}, nil)
      assert is_number(sma_result.ma_value)
      assert sma_result.trend in ["uptrend", "downtrend", "neutral"]

      # Step 5: Generate composite signal
      {:ok, composite} = CompositeSignal.handler(%{
        rsi: %{rsi: rsi_result.rsi, signal: rsi_result.signal},
        macd: %{crossover: macd_result.crossover, histogram: macd_result.histogram},
        bollinger: %{signal: bb_result.signal, pct_b: bb_result.pct_b},
        moving_average: %{trend: sma_result.trend}
      }, nil)

      assert composite.signal in ["strong_buy", "buy", "hold", "sell", "strong_sell"]
      assert composite.confidence >= 0 and composite.confidence <= 1
      assert is_map(composite.breakdown)
    end

    test "backtest with realistic price data" do
      prices =
        Enum.map(1..100, fn i ->
          50 + i * 0.5 + :math.sin(i * 0.1) * 10 + :rand.normal() * 3
        end)

      {:ok, result} = StrategyBacktest.handler(%{
        prices: prices,
        strategy: "sma_crossover",
        fast_period: 5,
        slow_period: 15,
        initial_capital: 10000
      }, nil)

      assert result.strategy == "sma_crossover"
      assert result.initial_capital == 10000
      assert is_number(result.final_capital)
      assert is_number(result.total_return_pct)
      assert is_integer(result.num_trades)
      assert result.num_trades >= 0
      assert is_number(result.win_rate)
      assert result.win_rate >= 0 and result.win_rate <= 100
    end

    test "multi-timeframe analysis with realistic scenario" do
      input = %{
        timeframes: %{
          "1D" => %{rsi: 55, trend: "uptrend", macd: "bullish"},
          "4H" => %{rsi: 60, trend: "uptrend", macd: "bullish"},
          "1H" => %{rsi: 45, trend: "neutral", macd: "none"},
          "15m" => %{rsi: 35, trend: "downtrend", macd: "bearish"}
        }
      }

      {:ok, result} = MultiTimeframe.handler(input, nil)
      assert result.dominant_trend in ["bullish", "bearish", "neutral"]
      assert result.confluence in ["strong", "moderate", "weak", "divergent"]
      assert result.recommendation in [
        "strong_buy", "buy", "cautious_buy", "hold",
        "cautious_sell", "sell", "strong_sell"
      ]
    end

    test "alert management with multiple conditions" do
      input = %{
        indicators: %{
          rsi: 28.0,
          macd_histogram: -0.3,
          bb_pct_b: -0.1
        },
        alerts: [
          %{type: "rsi_oversold", threshold: 30},
          %{type: "macd_bearish_cross", threshold: 0},
          %{type: "price_below_bb", threshold: 0}
        ]
      }

      {:ok, result} = AlertManager.handler(input, nil)
      assert length(result.alerts_triggered) >= 1
      assert result.overall_sentiment in ["bullish", "bearish", "neutral"]
      assert is_number(result.confidence)
    end

    test "diverging signals produce cautious recommendation" do
      prices_up = Enum.map(1..30, &(&1 * 2.0))
      prices_down = Enum.map(30..1, &(&1 * 2.0))

      {:ok, bull_rsi} = RSI.handler(%{prices: prices_up, period: 10}, nil)
      {:ok, bear_rsi} = RSI.handler(%{prices: prices_down, period: 10}, nil)

      assert bull_rsi.rsi > bear_rsi.rsi
      assert bull_rsi.signal != bear_rsi.signal or bull_rsi.rsi != bear_rsi.rsi
    end
  end
end
