defmodule Lux.Integrations.Binance.ExchangeTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.Exchange

  describe "market_request/3" do
    test "builds spot and futures public request plans" do
      assert {:ok, spot} = Exchange.market_request(:spot, :ticker_price, %{symbol: "ethusdt"})
      assert spot.base_url == "https://api.binance.com"
      assert spot.endpoint == "/api/v3/ticker/price"
      assert spot.params == %{symbol: "ETHUSDT"}
      assert spot.security_type == :none

      assert {:ok, futures} =
               Exchange.market_request(:futures, :klines, %{
                 symbol: "BTCUSDT",
                 interval: "1m",
                 limit: 100
               })

      assert futures.base_url == "https://fapi.binance.com"
      assert futures.endpoint == "/fapi/v1/klines"
      assert futures.params == %{symbol: "BTCUSDT", interval: "1m", limit: 100}
    end

    test "validates required public request params" do
      assert Exchange.market_request(:spot, :klines, %{symbol: "BTCUSDT"}) ==
               {:error, "Kline requests require symbol and interval"}

      assert Exchange.market_request(:spot, :unknown) ==
               {:error, "Unsupported Binance market data request: unknown"}
    end
  end

  describe "order_plan/1" do
    test "normalizes limit and futures order parameters" do
      assert {:ok, order} =
               Exchange.order_plan(%{
                 symbol: "ethusdt",
                 side: :buy,
                 type: :limit,
                 quantity: "1.25",
                 price: "3100.5",
                 position_side: :long,
                 client_order_id: "lux-1"
               })

      assert order.symbol == "ETHUSDT"
      assert order.side == "BUY"
      assert order.type == "LIMIT"
      assert order.quantity == 1.25
      assert order.price == 3100.5
      assert order.time_in_force == "GTC"
      assert order.position_side == "LONG"
      assert order.client_order_id == "lux-1"
    end

    test "rejects unsafe orders" do
      assert Exchange.order_plan(%{side: :buy, type: :market, quantity: 1}) ==
               {:error, "Missing Binance symbol"}

      assert Exchange.order_plan(%{symbol: "ETHUSDT", side: :hold, type: :market, quantity: 1}) ==
               {:error, "Unsupported Binance order side"}

      assert Exchange.order_plan(%{symbol: "ETHUSDT", side: :buy, type: :market, quantity: 0}) ==
               {:error, "Order quantity must be positive"}
    end
  end

  describe "signed_request/3" do
    test "builds signed order request plans without signing secrets" do
      assert {:ok, request} =
               Exchange.signed_request(:futures, :create_order, %{
                 api_key: "key",
                 timestamp: 1_700_000_000_000,
                 symbol: "btcusdt",
                 side: "SELL",
                 type: "MARKET",
                 quantity: 0.5,
                 reduce_only: true,
                 position_side: "SHORT"
               })

      assert request.method == :post
      assert request.endpoint == "/fapi/v1/order"
      assert request.headers == [{"X-MBX-APIKEY", "key"}]
      assert request.security_type == :signed
      assert request.params.symbol == "BTCUSDT"
      assert request.params.reduceOnly == true
      assert request.params.positionSide == "SHORT"
      assert request.query_to_sign =~ "quantity=0.5"
      assert request.query_to_sign =~ "reduceOnly=true"
      assert request.query_to_sign =~ "timestamp=1700000000000"
    end
  end

  describe "websocket_plan/2" do
    test "builds combined stream urls" do
      assert {:ok, plan} =
               Exchange.websocket_plan(:spot, [
                 %{symbol: "ETHUSDT", channel: "ticker"},
                 %{symbol: "BTCUSDT", channel: "kline", interval: "1m"}
               ])

      assert plan.base_url == "wss://stream.binance.com:9443"
      assert plan.streams == ["ethusdt@ticker", "btcusdt@kline_1m"]
      assert plan.url =~ "ethusdt@ticker/btcusdt@kline_1m"
    end
  end

  describe "weight_summary/2 and portfolio_snapshot/1" do
    test "tracks rate-limit weight and portfolio balances" do
      requests = [
        %{weight: 10},
        %{weight: 20},
        %{weight: 5}
      ]

      assert Exchange.weight_summary(requests, %{limit_per_minute: 40}) == %{
               request_count: 3,
               used_weight: 35,
               limit_per_minute: 40,
               remaining_weight: 5,
               allowed?: true,
               utilization: 0.875
             }

      snapshot =
        Exchange.portfolio_snapshot(%{
          balances: [
            %{asset: "USDT", free: "100.5", locked: "1.5"},
            %{asset: "ETH", free: 2, locked: 0}
          ],
          positions: [
            %{
              symbol: "BTCUSDT",
              position_amt: "-0.25",
              entry_price: "65000",
              mark_price: "64000",
              unrealized_pnl: "250",
              leverage: "5"
            }
          ]
        })

      assert snapshot.total_free == 102.5
      assert snapshot.total_locked == 1.5
      assert snapshot.unrealized_pnl == 250.0
      assert snapshot.open_position_count == 1
    end
  end
end
