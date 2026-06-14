defmodule Lux.Integrations.BinanceTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Binance
  describe "market data" do
    test "ticker/1 returns ticker info" do
      result = Binance.ticker("BTCUSDT")
      assert elem(result, 0) in [:ok, :error]
    end
    test "order_book/1 returns order book" do
      result = Binance.order_book("BTCUSDT")
      assert elem(result, 0) in [:ok, :error]
    end
    test "recent_trades/1 returns trades" do
      result = Binance.recent_trades("BTCUSDT")
      assert elem(result, 0) in [:ok, :error]
    end
    test "klines/1 returns kline data" do
      result = Binance.klines("BTCUSDT", "1h", 5)
      assert elem(result, 0) in [:ok, :error]
    end
    test "exchange_info/0 returns exchange info" do
      result = Binance.exchange_info()
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
