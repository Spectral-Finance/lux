defmodule Lux.Exchanges.CoinbaseTest do
  use ExUnit.Case, async: true
  alias Lux.Exchanges.Coinbase

  test "signs Coinbase Advanced Trade request and builds validated limit order" do
    sig = Coinbase.sign_request("1700000000", "POST", "/api/v3/brokerage/orders", ~s({"product_id":"BTC-USD"}), "cb_secret")
    assert byte_size(sig) == 64

    {:ok, order} =
      Coinbase.build_order(%{
        product_id: "BTC-USD",
        side: :buy,
        type: :limit,
        base_size: 0.5,
        limit_price: 80_500.0,
        post_only: true
      })

    assert order.product_id == "BTC-USD"
    assert order.side == "BUY"
    assert order.order_configuration.limit_limit_gtc.post_only == true
  end
end
