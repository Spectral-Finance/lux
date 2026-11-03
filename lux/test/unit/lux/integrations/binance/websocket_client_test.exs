defmodule Lux.Integrations.Binance.WebsocketClientTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.WebsocketClient

  describe "url builders" do
    test "builds single stream urls" do
      assert WebsocketClient.single_stream_url(:spot, "BTCUSDT", "depth20@100ms") ==
               "wss://stream.binance.com:9443/ws/btcusdt@depth20@100ms"

      assert WebsocketClient.single_stream_url(:futures, "ETHUSDT", "markPrice@1s") ==
               "wss://fstream.binance.com/ws/ethusdt@markPrice@1s"
    end

    test "builds combined stream urls" do
      streams = ["btcusdt@trade", "ethusdt@kline_1m"]
      assert WebsocketClient.combined_streams_url(:spot, streams) ==
               "wss://stream.binance.com:9443/stream?streams=btcusdt@trade/ethusdt@kline_1m"
    end
  end

  describe "parse_event/1" do
    test "parses orderbook depth event" do
      event = %{
        "e" => "depthUpdate",
        "E" => 123456789,
        "s" => "BNBUSDT",
        "U" => 157,
        "u" => 160,
        "b" => [["600.50", "1.5"]],
        "a" => [["600.60", "2.0"]]
      }

      assert {:ok, :orderbook_update, data} = WebsocketClient.parse_event(event)
      assert data.symbol == "BNBUSDT"
      assert data.bids == [{600.50, 1.5}]
      assert data.asks == [{600.60, 2.0}]
    end

    test "parses trade tick event" do
      event = %{
        "e" => "trade",
        "E" => 123456789,
        "s" => "BNBUSDT",
        "t" => 12345,
        "p" => "601.25",
        "q" => "0.5",
        "m" => true,
        "T" => 123456785
      }

      assert {:ok, :trade, data} = WebsocketClient.parse_event(event)
      assert data.price == 601.25
      assert data.quantity == 0.5
      assert data.buyer_is_maker == true
    end

    test "parses futures mark price event" do
      event = %{
        "e" => "markPriceUpdate",
        "E" => 123456789,
        "s" => "BTCUSDT",
        "p" => "65123.40",
        "i" => "65120.00",
        "P" => "65150.00",
        "r" => "0.0001",
        "T" => 123456789
      }

      assert {:ok, :mark_price, data} = WebsocketClient.parse_event(event)
      assert data.mark_price == 65123.40
      assert data.funding_rate == 0.0001
    end
  end
end
