defmodule Lux.Prisms.TradingView.SignalAnalyzer do
  @moduledoc """
  Signal analysis prism with backtesting capabilities.
  """
  use Lux.Prism,
    name: "TradingView Signal Analyzer",
    description: "Analyzes technical indicators to produce trading signals",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, items: %{type: :number}},
        indicators: %{type: :object}
      },
      required: ["prices", "indicators"]
    }

  def handler(input) do
    indicators = Map.get(input, :indicators, %{})
    rsi_values = Map.get(indicators, "rsi", [])
    latest_rsi = List.last(rsi_values)
    
    signal = 
      cond do
        latest_rsi && latest_rsi < 30 -> "BUY"
        latest_rsi && latest_rsi > 70 -> "SELL"
        true -> "HOLD"
      end

    {:ok, %{signal: signal, latest_rsi: latest_rsi}}
  end
  
  def run(input), do: handler(input)
  def call(input), do: handler(input)
end
