defmodule Lux.Prisms.Binance.ExchangePrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.ExchangePrism

  test "signs requests with deterministic HMAC-SHA256" do
    params = %{symbol: "BTCUSDT", side: "BUY", quantity: 0.5, timestamp: 1_700_000_000_000}
    assert {:ok, signed} = ExchangePrism.sign_request(params, "test_secret_key", 5000)
    assert String.length(signed.signature) == 64
    assert String.contains?(signed.signed_query, "signature=#{signed.signature}")
  end

  test "builds spot and USD-M futures orders and validates leverage/price" do
    assert {:ok, spot} =
             ExchangePrism.build_spot_order(%{
               symbol: "ethusdt",
               side: "BUY",
               type: "LIMIT",
               quantity: 2.5,
               price: 3100.0
             })

    assert spot.symbol == "ETHUSDT"
    assert spot.price == 3100.0

    assert {:ok, fut} =
             ExchangePrism.build_futures_order(%{
               symbol: "solusdt",
               side: "SELL",
               type: "LIMIT",
               quantity: 25.0,
               price: 185.5,
               leverage: 10,
               reduce_only: true
             })

    assert fut.symbol == "SOLUSDT"
    assert fut.leverage == 10
    assert fut.reduceOnly == true
  end

  test "builds WebSocket subscriptions, summarizes portfolio, and enforces rate limits" do
    assert {:ok, ws} =
             ExchangePrism.build_ws_subscription(["BTCUSDT@aggTrade", "ETHUSDT@depth20@100ms"], 7)

    assert ws.params == ["btcusdt@aggtrade", "ethusdt@depth20@100ms"]

    assert {:ok, port} =
             ExchangePrism.summarize_portfolio(
               [%{asset: "USDT", free: 10_000.0, locked: 500.0, price_usd: 1.0}],
               [%{symbol: "BTCUSDT", unrealized_pnl_usd: 450.25}]
             )

    assert port.total_equity_usd == 10_950.25

    assert {:ok, rl_ok} = ExchangePrism.check_rate_limit(300, 10, 5)
    assert rl_ok.action == :allow

    assert {:ok, rl_Wait} = ExchangePrism.check_rate_limit(1198, 10, 5)
    assert rl_Wait.action == :backoff_required
  end
end
