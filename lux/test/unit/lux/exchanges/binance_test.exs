defmodule Lux.Exchanges.BinanceTest do
  use ExUnit.Case, async: true
  alias Lux.Exchanges.Binance

  test "signs authenticated query with HMAC-SHA256 and analyzes orderbook VWAP" do
    sig = Binance.sign_query("symbol=BTCUSDT&side=BUY&timestamp=1700000000000", "test_secret")
    assert byte_size(sig) == 64

    book = %{
      bids: [[81000.0, 1.5], [80990.0, 2.0]],
      asks: [[81010.0, 1.0], [81020.0, 3.0]]
    }

    {:ok, metrics} = Binance.analyze_orderbook(book, 2.0)
    assert metrics.best_bid == 81000.0
    assert metrics.best_ask == 81010.0
    assert metrics.vwap_buy_price == 81015.0
  end
end
