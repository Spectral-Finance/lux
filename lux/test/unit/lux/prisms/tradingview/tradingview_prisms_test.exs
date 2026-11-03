defmodule Lux.Prisms.TradingViewPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.IndicatorCalculatorPrism
  alias Lux.Prisms.TradingView.SignalGeneratorPrism
  alias Lux.Prisms.TradingView.MultiTimeframePrism
  alias Lux.Prisms.TradingView.StrategyBacktestPrism
  alias Lux.Prisms.TradingView.TradingViewAlertPrism

  @sample_prices [
    44.0, 44.5, 45.0, 45.5, 46.0, 46.5, 47.0, 47.5, 48.0, 48.5,
    49.0, 49.5, 50.0, 50.5, 51.0, 51.5, 52.0, 52.5, 53.0, 53.5,
    54.0, 54.5, 55.0, 55.5, 56.0, 56.5, 57.0, 57.5, 58.0, 58.5
  ]

  describe "IndicatorCalculatorPrism" do
    test "computes indicators" do
      input = %{prices: @sample_prices}
      assert {:ok, result} = IndicatorCalculatorPrism.run(input)
      assert result.current_price == 58.5
      assert is_float(result.rsi)
      assert is_map(result.bollinger_bands)
    end
  end

  describe "SignalGeneratorPrism" do
    test "generates signal" do
      input = %{
        current_price: 58.5,
        rsi: 72.0,
        macd: %{macd_line: 1.2, histogram: 0.5},
        bollinger_bands: %{lower_band: 50.0, upper_band: 60.0}
      }

      assert {:ok, result} = SignalGeneratorPrism.run(input)
      assert is_integer(result.score)
      assert is_binary(result.recommendation)
    end
  end

  describe "MultiTimeframePrism" do
    test "calculates consensus" do
      input = %{
        timeframe_signals: [
          %{recommendation: :buy},
          %{recommendation: :buy}
        ]
      }

      assert {:ok, result} = MultiTimeframePrism.run(input)
      assert result.overall_bias == "BULLISH"
      assert result.consensus_pct == 100.0
    end
  end

  describe "StrategyBacktestPrism" do
    test "runs strategy backtest" do
      input = %{prices: @sample_prices, fast_ma: 5, slow_ma: 10}
      assert {:ok, result} = StrategyBacktestPrism.run(input)
      assert is_integer(result.total_trades)
      assert is_float(result.win_rate_pct)
    end
  end

  describe "TradingViewAlertPrism" do
    test "triggers overbought alert" do
      input = %{
        symbol: "BTCUSDT",
        current_price: 68000.0,
        rsi: 75.0
      }

      assert {:ok, result} = TradingViewAlertPrism.run(input)
      assert result.has_alerts? == true
      assert length(result.alerts) > 0
    end
  end
end
