defmodule Lux.Integrations.Coinbase.AdvancedTradeTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.AdvancedTrade

  @attrs %{
    product_id: "BTC-USD",
    account_id: "account-1",
    portfolio_id: "portfolio-1",
    order_id: "order-1",
    side: "buy",
    order_type: "limit",
    base_size: "0.01",
    limit_price: "65000",
    post_only: true,
    channels: ["ticker", "level2", "heartbeats", "unknown"],
    market_data: %{
      product: %{
        product_id: "BTC-USD",
        base_currency: "BTC",
        quote_currency: "USD",
        price_increment: "0.01",
        base_increment: "0.00000001"
      },
      ticker: %{product_id: "BTC-USD", price: "65010", best_bid: "65000", best_ask: "65020"},
      book: %{
        bids: [%{price: "65000", size: "1.5"}, %{price: "64990", size: "2.0"}],
        asks: [%{price: "65020", size: "1.0"}, %{price: "65030", size: "2.2"}],
        sequence: 42
      },
      trades: [
        %{trade_id: "t1", product_id: "BTC-USD", price: "65015", size: "0.1", side: "BUY"},
        %{trade_id: "t2", product_id: "BTC-USD", price: "65000", size: "0.2", side: "SELL"}
      ],
      candles: [
        %{start: "1", low: "64000", high: "66000", open: "64500", close: "65000", volume: "10"}
      ]
    },
    accounts: [
      %{uuid: "btc", currency: "BTC", available_balance: %{value: "0.5", currency: "BTC"}},
      %{uuid: "usd", currency: "USD", available_balance: %{value: "1000", currency: "USD"}}
    ],
    prices: %{"BTC" => "65000"},
    request_history: [%{action: :accounts}, %{action: :orders}, %{action: :create_order}],
    rate_limit: 5
  }

  test "builds REST plans for public and private Coinbase endpoints" do
    plans = AdvancedTrade.rest_plans(@attrs)

    assert length(plans) == 13
    assert Enum.any?(plans, &(&1.action == :list_products and not &1.auth_required))
    create_order = Enum.find(plans, &(&1.action == :create_order))

    assert create_order.method == :post
    assert create_order.auth_required
    assert create_order.jwt_claims.signing_required_in_transport
    assert create_order.body.product_id == "BTC-USD"
    assert create_order.body.order_configuration.limit_limit_gtc.limit_price == "65000"
    assert create_order.idempotency_key == "lux-coinbase-btc-usd-buy-limit"
  end

  test "builds market, limit, and stop limit order payloads" do
    market =
      AdvancedTrade.order_payload(%{
        product_id: "ETH-USD",
        order_type: "market",
        quote_size: "100"
      })

    limit =
      AdvancedTrade.order_payload(%{
        product_id: "ETH-USD",
        order_type: "limit",
        base_size: "1",
        limit_price: "3000"
      })

    stop =
      AdvancedTrade.order_payload(%{
        product_id: "ETH-USD",
        order_type: "stop-limit",
        base_size: "1",
        limit_price: "2950",
        stop_price: "2900"
      })

    assert market.order_configuration.market_market_ioc.quote_size == "100"
    assert limit.order_configuration.limit_limit_gtc.base_size == "1"
    assert stop.order_configuration.stop_limit_stop_limit_gtc.stop_price == "2900"
  end

  test "builds WebSocket subscription plans with channel filtering and auth detection" do
    public = AdvancedTrade.websocket_subscription(["ticker", "level2", "bad"], ["BTC-USD"], false)
    private = AdvancedTrade.websocket_subscription(["user"], ["BTC-USD"], false)

    assert public.channels == ["ticker", "level2"]
    refute public.auth_required
    assert private.auth_required
    assert private.sequence_tracking
  end

  test "normalizes market data and computes order book signals" do
    snapshot = AdvancedTrade.market_snapshot(@attrs.market_data)

    assert snapshot.product.product_id == "BTC-USD"
    assert snapshot.best_bid.price == 65000.0
    assert snapshot.best_ask.price == 65020.0
    assert snapshot.mid_price == 65010.0
    assert snapshot.trade_volume == 0.3
    assert snapshot.candle_count == 1
  end

  test "computes portfolio snapshots from accounts and reference prices" do
    portfolio = AdvancedTrade.portfolio_snapshot(@attrs.accounts, @attrs.prices)

    assert portfolio.account_count == 2
    assert portfolio.total_value_usd == 33500.0
    assert Enum.any?(portfolio.positions, &(&1.currency == "BTC" and &1.value_usd == 32500.0))
  end

  test "summarizes rate-limit usage" do
    budget = AdvancedTrade.rate_limit_budget(@attrs.request_history, %{rate_limit: 3})

    assert budget.used == 3
    assert budget.remaining == 0
    assert budget.throttled?
    assert budget.retry_after_ms == 1000
  end

  test "builds full operation plan and accepts string keyed input" do
    plan =
      AdvancedTrade.plan(%{
        "product_id" => "SOL-USD",
        "side" => "SELL",
        "order_type" => "market",
        "base_size" => "2",
        "channels" => ["ticker", "heartbeats"],
        "accounts" => [%{"currency" => "SOL", "available_balance" => %{"value" => "5"}}],
        "prices" => %{"SOL" => "150"}
      })

    assert :order_management in plan.coverage
    assert plan.order_management.create_order.product_id == "SOL-USD"
    assert plan.order_management.create_order.side == "SELL"
    assert plan.websocket.heartbeat_required
    assert plan.portfolio.total_value_usd == 750.0
    refute plan.safety.submits_live_orders
  end
end
