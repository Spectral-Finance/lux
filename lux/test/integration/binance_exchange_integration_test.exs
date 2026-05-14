defmodule Lux.Integration.BinanceExchangeIntegrationTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Binance.Exchange

  test "builds an end-to-end Binance spot and futures workflow without live credentials" do
    assert {:ok, plan} =
             Exchange.trading_system_plan(%{
               market_data: [
                 %{
                   market: :spot,
                   endpoint: :order_book,
                   symbol: "BTCUSDT",
                   params: %{limit: 100}
                 },
                 %{
                   market: :futures,
                   endpoint: :klines,
                   symbol: "ETHUSDT",
                   params: %{interval: "1m", limit: 50}
                 }
               ],
               websocket: %{
                 market: :futures,
                 subscriptions: [
                   %{symbol: "btcusdt", stream: :mark_price},
                   %{symbol: "ethusdt", stream: :book_ticker}
                 ]
               },
               spot_orders: [
                 %{
                   symbol: "BNBUSDT",
                   side: :buy,
                   type: :limit,
                   quantity: "1.5",
                   price: "310",
                   client_order_id: "lux-spot-integration",
                   timestamp: 1_700_000_000_000
                 }
               ],
               futures_orders: [
                 %{
                   symbol: "ETHUSDT",
                   side: :sell,
                   type: :market,
                   quantity: "0.25",
                   reduce_only: true,
                   position_side: "SHORT",
                   timestamp: 1_700_000_000_100
                 }
               ],
               portfolio: %{
                 spot_balances: [%{asset: "USDT", free: "1000", locked: "10"}],
                 futures_positions: [
                   %{
                     symbol: "ETHUSDT",
                     positionAmt: "-0.25",
                     markPrice: "3000",
                     unRealizedProfit: "12"
                   }
                 ]
               },
               rate_limits: %{limit_per_minute: 100}
             })

    assert plan.ready
    assert Enum.all?(plan.spot_orders ++ plan.futures_orders, & &1.validation.valid)
    assert plan.websocket.market == :futures
    assert plan.portfolio.totals.spot_assets == 1
    assert plan.portfolio.totals.futures_positions == 1
    assert plan.rate_limits.compliant
  end
end
