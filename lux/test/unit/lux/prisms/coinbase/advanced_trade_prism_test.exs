defmodule Lux.Prisms.Coinbase.AdvancedTradePrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Coinbase.AdvancedTradePrism

  test "generates CB-ACCESS-* auth headers and builds limit/stop-limit orders" do
    assert {:ok, headers} =
             AdvancedTradePrism.build_auth_headers(
               "cb_key_1",
               "cb_secret_1",
               "POST",
               "/api/v3/brokerage/orders",
               "{\"product_id\":\"BTC-USD\"}",
               1_700_000_000
             )

    assert headers["CB-ACCESS-KEY"] == "cb_key_1"
    assert String.length(headers["CB-ACCESS-SIGN"]) == 64

    assert {:ok, limit_order} =
             AdvancedTradePrism.build_order(%{
               client_order_id: "ord-101",
               product_id: "btc-usd",
               side: "BUY",
               order_type: :limit_gtc,
               base_size: 0.25,
               limit_price: 89_000.0,
               post_only: true
             })

    assert limit_order.product_id == "BTC-USD"
    assert limit_order.order_configuration.limit_limit_gtc.post_only == true
  end

  test "builds WebSocket subscriptions, summarizes accounts, normalizes candles, and checks rate limit" do
    assert {:ok, ws} =
             AdvancedTradePrism.build_ws_subscribe("level2", ["btc-usd", "eth-usd"], 1_700_000_000)

    assert ws.product_ids == ["BTC-USD", "ETH-USD"]

    assert {:ok, summary} =
             AdvancedTradePrism.summarize_accounts([
               %{currency: "USDC", available: 12_000.0, hold: 500.0, price_usd: 1.0},
               %{currency: "ETH", available: 2.0, hold: 0.0, price_usd: 3_000.0}
             ])

    assert summary.total_portfolio_usd == 18_500.0

    assert {:ok, candles} =
             AdvancedTradePrism.normalize_candles([
               %{start: 200, open: 100.0, high: 105.0, low: 97.0, close: 104.0, volume: 50.0},
               %{start: 100, open: 95.0, high: 102.0, low: 94.0, close: 100.0, volume: 40.0}
             ])

    assert hd(candles).start == 100
    assert hd(candles).typical_price == 98.6667

    assert {:ok, rl} = AdvancedTradePrism.check_rate_limit(29, 2)
    assert rl.status == :backoff_required
  end
end
