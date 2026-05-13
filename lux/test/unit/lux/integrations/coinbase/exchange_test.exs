defmodule Lux.Integrations.Coinbase.ExchangeTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.Exchange

  describe "public_request/2" do
    test "builds public market data request plans" do
      assert {:ok, product} = Exchange.public_request(:product, %{product_id: "btc_usd"})
      assert product.method == :get
      assert product.url == "https://api.coinbase.com/api/v3/brokerage/products/BTC-USD"
      assert product.security_type == :none

      assert {:ok, book} = Exchange.public_request(:product_book, %{symbol: "eth-usd", limit: 50})
      assert book.path == "/api/v3/brokerage/product_book"
      assert book.params == %{product_id: "ETH-USD", limit: 50}
      assert book.weight == 2
    end

    test "validates public request parameters" do
      assert Exchange.public_request(:product, %{}) == {:error, "Coinbase request requires product_id"}

      assert Exchange.public_request(:candles, %{product_id: "BTC-USD", start: "1", end: "2"}) ==
               {:error, "Coinbase candles require start, end, and granularity"}

      assert Exchange.public_request(:unknown, %{}) ==
               {:error, "Unsupported Coinbase public request: unknown"}
    end
  end

  describe "order_plan/1" do
    test "normalizes market and limit orders" do
      assert {:ok, market} =
               Exchange.order_plan(%{
                 product_id: "btc_usd",
                 side: :buy,
                 type: :market,
                 quote_size: "100.50"
               })

      assert market.product_id == "BTC-USD"
      assert market.side == "BUY"
      assert market.order_configuration == %{market_market_ioc: %{quote_size: "100.5"}}

      assert {:ok, limit} =
               Exchange.order_plan(%{
                 symbol: "eth-usd",
                 side: "SELL",
                 order_type: "LIMIT",
                 base_size: 1.25,
                 limit_price: "3100.00",
                 post_only: true
               })

      assert limit.order_configuration == %{
               limit_limit_gtc: %{base_size: "1.25", limit_price: "3100", post_only: true}
             }
    end

    test "rejects unsafe or incomplete order plans" do
      assert Exchange.order_plan(%{side: :buy, type: :market, base_size: 1}) ==
               {:error, "Missing Coinbase product_id"}

      assert Exchange.order_plan(%{product_id: "BTC-USD", side: :hold, type: :market, base_size: 1}) ==
               {:error, "Unsupported Coinbase order side"}

      assert Exchange.order_plan(%{product_id: "BTC-USD", side: :buy, type: :market}) ==
               {:error, "Coinbase market orders require base_size or quote_size"}
    end
  end

  describe "signed_request/2" do
    test "builds signed request plans without signing secrets" do
      assert {:ok, request} =
               Exchange.signed_request(:create_order, %{
                 jwt: "token",
                 api_key_name: "organizations/org/apiKeys/key",
                 issued_at: 1_700_000_000,
                 client_order_id: "lux-1",
                 product_id: "BTC-USD",
                 side: "BUY",
                 type: "MARKET",
                 base_size: "0.1"
               })

      assert request.method == :post
      assert request.path == "/api/v3/brokerage/orders"
      assert request.headers == [{"Authorization", "Bearer token"}]
      assert request.jwt_claims.uri == "POST api.coinbase.com/api/v3/brokerage/orders"
      assert request.jwt_claims.exp == 1_700_000_120
      assert request.body.client_order_id == "lux-1"
      assert request.body.order_configuration == %{market_market_ioc: %{base_size: "0.1"}}
    end

    test "builds account and cancel-order plans" do
      assert {:ok, account} =
               Exchange.signed_request(:account, %{
                 account_uuid: "acc-1",
                 issued_at: 10
               })

      assert account.path == "/api/v3/brokerage/accounts/acc-1"
      assert account.jwt_claims.uri == "GET api.coinbase.com/api/v3/brokerage/accounts/acc-1"

      assert {:ok, cancel} = Exchange.signed_request(:cancel_orders, %{order_ids: ["o1", "o2"]})
      assert cancel.body == %{order_ids: ["o1", "o2"]}
    end
  end

  describe "websocket_subscription/3" do
    test "builds websocket subscribe messages" do
      assert {:ok, sub} =
               Exchange.websocket_subscription([:ticker, "level2"], ["btc_usd", "ETH-USD"], %{jwt: "token"})

      assert sub.url == "wss://advanced-trade-ws.coinbase.com"
      assert sub.message == %{
               type: "subscribe",
               product_ids: ["BTC-USD", "ETH-USD"],
               channel_names: ["ticker", "level2"],
               jwt: "token"
             }
    end

    test "validates websocket channels and products" do
      assert Exchange.websocket_subscription([], ["BTC-USD"]) ==
               {:error, "At least one Coinbase WebSocket channel is required"}

      assert Exchange.websocket_subscription([:ticker], []) ==
               {:error, "At least one Coinbase product_id is required"}
    end
  end

  describe "rate_limit_summary/2 and portfolio_snapshot/1" do
    test "summarizes request budgets and account balances" do
      assert Exchange.rate_limit_summary([%{weight: 2}, %{weight: 3}], %{limit_per_second: 10}) == %{
               request_count: 2,
               used_weight: 5,
               limit_per_second: 10,
               remaining_weight: 5,
               allowed?: true,
               utilization: 0.5
             }

      snapshot =
        Exchange.portfolio_snapshot(%{
          accounts: [
            %{uuid: "btc", currency: "BTC", available_balance: %{value: "0.25"}, hold: "0.01"},
            %{uuid: "usd", currency: "USD", available: "100.50", hold_balance: 0}
          ],
          portfolios: [%{uuid: "p1", name: "Default", type: "DEFAULT"}]
        })

      assert snapshot.total_available == 100.75
      assert snapshot.total_hold == 0.01
      assert snapshot.asset_count == 2
      assert hd(snapshot.portfolios).name == "Default"
    end
  end
end
