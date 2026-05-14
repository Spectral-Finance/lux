defmodule Lux.Integrations.Binance.ExchangeTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.Exchange

  describe "rest_request_plan/1" do
    test "builds public spot market data requests" do
      assert {:ok, plan} =
               Exchange.rest_request_plan(%{
                 market: :spot,
                 endpoint: :order_book,
                 symbol: "eth/usdt"
               })

      assert plan.method == :get
      assert plan.signed == false
      assert plan.weight == 5
      assert plan.params["symbol"] == "ETHUSDT"
      assert plan.params["limit"] == 100
      assert plan.url == "https://api.binance.com/api/v3/depth?limit=100&symbol=ETHUSDT"
    end

    test "builds signed request payloads without signatures or keys" do
      assert {:ok, plan} =
               Exchange.rest_request_plan(%{
                 market: :futures,
                 endpoint: :open_orders,
                 symbol: "btcusdt",
                 timestamp: 1_700_000_000_000
               })

      assert plan.signed
      assert {"x-mbx-apikey", "<api-key>"} in plan.headers
      assert plan.params["timestamp"] == 1_700_000_000_000

      assert plan.signature_payload ==
               "recvWindow=5000&symbol=BTCUSDT&timestamp=1700000000000"
    end
  end

  describe "order planning" do
    test "normalizes spot limit orders and prepares signed order requests" do
      assert {:ok, plan} =
               Exchange.spot_order_plan(%{
                 symbol: "bnb/usdt",
                 side: :buy,
                 type: :limit,
                 quantity: "2.5",
                 price: "310.00",
                 client_order_id: "lux-test-1",
                 timestamp: 123
               })

      assert plan.order["symbol"] == "BNBUSDT"
      assert plan.order["side"] == "BUY"
      assert plan.order["type"] == "LIMIT"
      assert plan.order["timeInForce"] == "GTC"
      assert plan.validation.valid
      assert plan.request.endpoint == :new_order
      assert plan.request.signature_payload =~ "newClientOrderId=lux-test-1"
    end

    test "normalizes futures reduce-only market orders" do
      assert {:ok, plan} =
               Exchange.futures_order_plan(%{
                 symbol: "ethusdt",
                 side: "SELL",
                 type: "MARKET",
                 quantity: "0.25",
                 reduce_only: true,
                 position_side: "SHORT",
                 leverage: 3,
                 timestamp: 456
               })

      assert plan.order["symbol"] == "ETHUSDT"
      assert plan.order["type"] == "MARKET"
      refute Map.has_key?(plan.order, "price")
      refute Map.has_key?(plan.order, "timeInForce")
      assert plan.order["reduceOnly"]
      assert plan.margin.leverage == 3
      assert plan.validation.valid
    end

    test "reports validation errors for incomplete limit orders" do
      assert {:ok, plan} =
               Exchange.spot_order_plan(%{
                 symbol: "SOLUSDT",
                 side: :buy,
                 type: :limit,
                 quantity: "1",
                 timestamp: 789
               })

      refute plan.validation.valid
      assert :missing_limit_price in plan.validation.errors
    end
  end

  describe "websocket, portfolio, and rate limits" do
    test "builds combined websocket stream plans" do
      assert {:ok, plan} =
               Exchange.websocket_plan(%{
                 market: :futures,
                 subscriptions: [
                   %{symbol: "btcusdt", stream: :mark_price},
                   %{symbol: "ethusdt", stream: :book_ticker}
                 ]
               })

      assert plan.market == :futures
      assert plan.streams == ["btcusdt@markPrice", "ethusdt@bookTicker"]

      assert plan.url ==
               "wss://fstream.binance.com/stream?streams=btcusdt@markPrice/ethusdt@bookTicker"
    end

    test "normalizes portfolio balances and futures positions" do
      assert {:ok, snapshot} =
               Exchange.portfolio_snapshot(%{
                 account_id: "acct-1",
                 spot_balances: [
                   %{asset: "USDT", free: "100.5", locked: "2"},
                   %{asset: "ZERO", free: "0", locked: "0"}
                 ],
                 futures_positions: [
                   %{
                     symbol: "BTCUSDT",
                     positionAmt: "0.1",
                     entryPrice: "60000",
                     markPrice: "61000",
                     unRealizedProfit: "100"
                   }
                 ]
               })

      assert snapshot.account_id == "acct-1"
      assert [%{asset: "USDT", total: 102.5}] = snapshot.spot_balances
      assert [%{symbol: "BTCUSDT", notional: 6100.0}] = snapshot.futures_positions
      assert snapshot.totals.futures_unrealized_pnl == 100.0
    end

    test "checks Binance request-weight compliance" do
      requests = [
        %{market: :spot, endpoint: :order_book, count: 2},
        %{market: :futures, endpoint: :new_order, count: 3}
      ]

      assert {:ok, report} = Exchange.rate_limit_report(requests, %{limit_per_minute: 12})
      assert report.used_weight == 13
      refute report.compliant
      assert :over_limit in report.recommendations
    end
  end

  describe "trading_system_plan/1" do
    test "builds a full spot and futures integration plan" do
      assert {:ok, plan} =
               Exchange.trading_system_plan(%{
                 market_data: [
                   %{market: :spot, endpoint: :ticker_price, symbol: "BTCUSDT"},
                   %{market: :futures, endpoint: :ticker_24hr, symbol: "ETHUSDT"}
                 ],
                 websocket: %{
                   market: :spot,
                   subscriptions: [%{symbol: "btcusdt", stream: :ticker}]
                 },
                 spot_orders: [
                   %{
                     symbol: "BTCUSDT",
                     side: :buy,
                     type: :limit,
                     quantity: "0.01",
                     price: "60000",
                     timestamp: 111
                   }
                 ],
                 futures_orders: [
                   %{
                     symbol: "ETHUSDT",
                     side: :sell,
                     type: :market,
                     quantity: "0.5",
                     reduce_only: true,
                     timestamp: 222
                   }
                 ],
                 portfolio: %{spot_balances: [%{asset: "USDT", free: "1000", locked: "0"}]},
                 rate_limits: %{limit_per_minute: 100}
               })

      assert plan.ready
      assert length(plan.market_data) == 2
      assert length(plan.spot_orders) == 1
      assert length(plan.futures_orders) == 1
      assert plan.rate_limits.compliant
    end
  end
end
