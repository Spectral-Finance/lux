defmodule Lux.Prisms.TradingView.TradingViewPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.ChartDataPrism
  alias Lux.Prisms.TradingView.IndicatorCalculatorPrism
  alias Lux.Prisms.TradingView.PineScriptPrism
  alias Lux.Prisms.TradingView.SignalGeneratorPrism
  alias Lux.Prisms.TradingView.MultiTimeframePrism
  alias Lux.Prisms.TradingView.StrategyBacktestPrism
  alias Lux.Prisms.TradingView.TradingViewAlertPrism

  @sample_closes [
    44.34,
    44.09,
    44.15,
    43.61,
    44.33,
    44.83,
    45.10,
    45.42,
    45.84,
    46.08,
    45.89,
    46.03,
    45.61,
    46.28,
    46.28,
    46.00,
    46.03,
    46.41,
    46.22,
    45.64,
    46.00,
    46.50,
    47.10,
    47.50,
    47.20
  ]

  describe "ChartDataPrism" do
    test "fetches and formats candlestick data" do
      {:ok, result} =
        ChartDataPrism.run(%{symbol: "BTCUSDT", resolution: "1h", limit: 30, mock?: true})

      assert result.symbol == "BTCUSDT"
      assert result.count == 30
      assert is_float(result.current_price)
      assert length(result.candles) == 30
      assert length(result.close_prices) == 30
    end
  end

  describe "IndicatorCalculatorPrism" do
    test "calculates technical indicators on price series" do
      {:ok, result} = IndicatorCalculatorPrism.run(%{prices: @sample_closes})

      assert is_float(result.current_price)
      assert is_float(result.rsi)
      assert is_map(result.macd)
      assert is_map(result.bollinger_bands)
      assert is_float(result.ema_20)
    end
  end

  describe "PineScriptPrism" do
    test "evaluates boolean condition against context" do
      context = %{
        "close" => 105.0,
        "ema" => 100.0,
        "rsi" => 65.0
      }

      {:ok, result} =
        PineScriptPrism.run(%{
          script: "close > ema and rsi < 70",
          context: context
        })

      assert result.result == true
      assert result.triggered? == true
    end
  end

  describe "SignalGeneratorPrism" do
    test "outputs composite bias and recommendation" do
      {:ok, result} =
        SignalGeneratorPrism.run(%{
          current_price: 45.64,
          rsi: 28.0,
          macd: %{histogram: 0.8, trend: :bullish},
          bollinger_bands: %{upper: 50.0, lower: 40.0}
        })

      assert is_integer(result.score)
      assert result.recommendation in ["STRONG_BUY", "BUY", "NEUTRAL", "SELL", "STRONG_SELL"]
      assert result.rsi_signal in ["bullish", "bearish", "neutral"]
    end
  end

  describe "MultiTimeframePrism" do
    test "calculates multi-timeframe consensus" do
      {:ok, result} =
        MultiTimeframePrism.run(%{
          timeframe_signals: [
            %{timeframe: "15m", signal: :buy},
            %{timeframe: "1h", recommendation: :strong_buy},
            %{timeframe: "4h", score: 35}
          ]
        })

      assert result.overall_bias == "BULLISH"
      assert result.bullish_count == 3
      assert result.consensus_pct == 100.0
    end
  end

  describe "StrategyBacktestPrism" do
    test "executes backtest strategy and outputs trade metrics" do
      {:ok, result} =
        StrategyBacktestPrism.run(%{
          prices: @sample_closes,
          strategy: "ma_crossover",
          fast_ma: 3,
          slow_ma: 7
        })

      assert is_integer(result.total_trades)
      assert is_float(result.win_rate_pct)
      assert is_float(result.total_return_pct)
      assert is_float(result.max_drawdown_pct)
    end
  end

  describe "TradingViewAlertPrism" do
    test "evaluates threshold and triggers alert" do
      {:ok, result} =
        TradingViewAlertPrism.run(%{
          symbol: "BTCUSDT",
          current_price: 72000.0,
          rsi: 85.0,
          alerts: [
            %{id: "rsi_extreme", symbol: "BTCUSDT", condition: :rsi_overbought, threshold: 80.0}
          ]
        })

      assert result.symbol == "BTCUSDT"
      assert result.has_alerts? == true
      assert length(result.alerts) == 1
    end
  end
end
