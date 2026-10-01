defmodule Lux.Lenses.TradingView.MarketDataTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.TradingView.MarketData

  test "before_focus formats payload correctly" do
    {:ok, payload} = MarketData.before_focus(%{exchange: "BINANCE", symbol: "BTCUSDT"})
    assert payload["symbols"]["tickers"] == ["BINANCE:BTCUSDT"]
  end
end
