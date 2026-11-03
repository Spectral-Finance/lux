defmodule Lux.Beams.TradingView.TechnicalAnalysisBeam do
  @moduledoc """
  A coordinated workflow beam for technical indicator analysis and signal generation:
  1. Retrieves or accepts OHLCV chart data
  2. Computes technical indicators (RSI, MACD, Bollinger Bands) via IndicatorCalculatorPrism
  3. Generates composite market bias score and recommendation via SignalGeneratorPrism
  4. Evaluates custom Pine Script conditions via PineScriptPrism
  5. Checks trigger alerts for breakouts and threshold breaches via TradingViewAlertPrism
  """

  use Lux.Beam,
    name: "TradingView Technical Analysis Beam",
    description:
      "Computes technical indicators, determines bias recommendations, and monitors chart alerts",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Market symbol (e.g. BTCUSDT)"},
        prices: %{type: :array, description: "Historical close prices series"},
        script: %{type: :string, description: "Optional custom Pine Script condition"}
      },
      required: ["symbol", "prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        indicator_metrics: %{type: :object},
        signal_metrics: %{type: :object},
        alert_metrics: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.TradingView.IndicatorCalculatorPrism
  alias Lux.Prisms.TradingView.SignalGeneratorPrism
  alias Lux.Prisms.TradingView.TradingViewAlertPrism

  sequence do
    step(:indicators, IndicatorCalculatorPrism, %{
      prices: [:input, :prices]
    })

    step(:signals, SignalGeneratorPrism, %{
      current_price: [:steps, :indicators, :result, :current_price],
      rsi: [:steps, :indicators, :result, :rsi],
      macd: [:steps, :indicators, :result, :macd],
      bollinger_bands: [:steps, :indicators, :result, :bollinger_bands]
    })

    step(:alerts, TradingViewAlertPrism, %{
      symbol: [:input, :symbol],
      current_price: [:steps, :indicators, :result, :current_price],
      rsi: [:steps, :indicators, :result, :rsi]
    })
  end
end
