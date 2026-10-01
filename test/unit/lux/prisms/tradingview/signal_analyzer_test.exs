defmodule Lux.Prisms.TradingView.SignalAnalyzerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.TradingView.SignalAnalyzer

  test "generates BUY signal when RSI < 30" do
    {:ok, result} = SignalAnalyzer.handler(%{prices: [], indicators: %{"rsi" => [25.0]}})
    assert result.signal == "BUY"
  end

  test "generates SELL signal when RSI > 70" do
    {:ok, result} = SignalAnalyzer.handler(%{prices: [], indicators: %{"rsi" => [75.0]}})
    assert result.signal == "SELL"
  end
end
