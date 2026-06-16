defmodule Lux.Prisms.TradingView.AnalyzeSeries do
  @moduledoc """
  Calculates technical indicators and alerts for TradingView-style candles.
  """

  use Lux.Prism,
    name: "Analyze TradingView Series",
    description: "Calculates SMA, EMA, RSI, signal state, and alerts for OHLCV candles",
    input_schema: %{
      type: :object,
      properties: %{
        candles: %{type: :array},
        sma_period: %{type: :integer},
        ema_period: %{type: :integer},
        rsi_period: %{type: :integer}
      },
      required: ["candles"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        analysis: %{type: :object}
      },
      required: ["analysis"]
    }

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @impl true
  def handler(params, _ctx) do
    candles = Map.get(params, :candles, Map.get(params, "candles", []))

    opts = [
      sma_period: Map.get(params, :sma_period, Map.get(params, "sma_period", 20)),
      ema_period: Map.get(params, :ema_period, Map.get(params, "ema_period", 20)),
      rsi_period: Map.get(params, :rsi_period, Map.get(params, "rsi_period", 14))
    ]

    with {:ok, analysis} <- TechnicalAnalysis.analyze(candles, opts) do
      {:ok, %{analysis: analysis}}
    end
  end
end
