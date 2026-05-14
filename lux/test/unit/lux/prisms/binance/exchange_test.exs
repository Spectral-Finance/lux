defmodule Lux.Prisms.Binance.ExchangeTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.Exchange

  @ctx %{agent: %{name: "BinanceAgent"}}

  test "dispatches REST request planning" do
    assert {:ok, %{status: "success", result: result}} =
             Exchange.handler(
               %{
                 action: "rest_request",
                 params: %{market: :spot, endpoint: :ticker_price, symbol: "BTCUSDT"}
               },
               @ctx
             )

    assert result.endpoint == :ticker_price
    assert result.url == "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
  end

  test "dispatches full trading system planning" do
    assert {:ok, %{status: "success", result: result}} =
             Exchange.handler(
               %{
                 action: "trading_system",
                 params: %{
                   market_data: [%{market: :spot, endpoint: :ticker_price, symbol: "BTCUSDT"}],
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
                   futures_orders: [],
                   portfolio: %{spot_balances: [%{asset: "USDT", free: "1000", locked: "0"}]},
                   rate_limits: %{limit_per_minute: 100}
                 }
               },
               @ctx
             )

    assert result.ready
    assert result.websocket.streams == ["btcusdt@ticker"]
  end

  test "rejects unsupported actions" do
    assert {:error, "Unsupported Binance exchange operation"} =
             Exchange.handler(%{action: "unknown"}, @ctx)
  end
end
