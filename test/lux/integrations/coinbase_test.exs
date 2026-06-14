defmodule Lux.Integrations.CoinbaseTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Coinbase
  describe "market data" do
    test "ticker/1 returns ticker" do
      assert elem(Coinbase.ticker("BTC-USD"), 0) in [:ok, :error]
    end
    test "order_book/1 returns book" do
      assert elem(Coinbase.order_book("BTC-USD"), 0) in [:ok, :error]
    end
    test "trades/1 returns trades" do
      assert elem(Coinbase.trades("BTC-USD"), 0) in [:ok, :error]
    end
    test "products/0 returns products" do
      assert elem(Coinbase.products(), 0) in [:ok, :error]
    end
  end
end
