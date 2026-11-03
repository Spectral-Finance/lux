defmodule Lux.Integrations.Coinbase.WebsocketClientTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.WebsocketClient

  describe "ws_url/0" do
    test "returns advanced trade websocket url" do
      assert WebsocketClient.ws_url() == "wss://advanced-trade-ws.coinbase.com"
    end
  end

  describe "build_subscribe_message/2" do
    test "formats public subscription payload" do
      msg = WebsocketClient.build_subscribe_message("ticker", ["btc-usd", "eth-usd"])

      assert msg["type"] == "subscribe"
      assert msg["channel"] == "ticker"
      assert msg["product_ids"] == ["BTC-USD", "ETH-USD"]
    end
  end

  describe "parse_event/1" do
    test "parses ticker events" do
      event = %{
        "channel" => "ticker",
        "events" => [
          %{
            "type" => "snapshot",
            "tickers" => [
              %{
                "product_id" => "BTC-USD",
                "price" => "65000.50",
                "volume_24_h" => "1234.5",
                "low_24_h" => "64000.0",
                "high_24_h" => "66000.0",
                "price_percentage_chg_24_h" => "1.5"
              }
            ]
          }
        ]
      }

      assert {:ok, :ticker, [ticker]} = WebsocketClient.parse_event(event)
      assert ticker.product_id == "BTC-USD"
      assert ticker.price == 65000.50
      assert ticker.volume_24_h == 1234.5
    end

    test "parses market trade events" do
      event = %{
        "channel" => "market_trades",
        "events" => [
          %{
            "type" => "update",
            "trades" => [
              %{
                "trade_id" => "t-1",
                "product_id" => "BTC-USD",
                "price" => "65000.0",
                "size" => "0.25",
                "side" => "BUY",
                "time" => "2026-11-03T00:00:00Z"
              }
            ]
          }
        ]
      }

      assert {:ok, :market_trades, [trade]} = WebsocketClient.parse_event(event)
      assert trade.trade_id == "t-1"
      assert trade.size == 0.25
      assert trade.side == "BUY"
    end
  end
end
