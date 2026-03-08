defmodule Lux.Integrations.Binance.WebSocketTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Binance.WebSocket

  describe "valid_stream_types/0" do
    test "returns supported stream types" do
      types = WebSocket.valid_stream_types()
      assert "trade" in types
      assert "kline" in types
      assert "depth" in types
      assert "ticker" in types
      assert "miniTicker" in types
      assert "bookTicker" in types
      assert "aggTrade" in types
      assert "markPrice" in types
      assert "forceOrder" in types
    end
  end

  describe "ws_url/1" do
    test "returns spot URL by default" do
      assert WebSocket.ws_url() =~ "stream.binance.com"
    end

    test "returns futures URL when futures: true" do
      assert WebSocket.ws_url(true) =~ "fstream.binance.com"
    end
  end

  describe "start_link/1 with auto_connect: false" do
    test "starts spot connection" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@trade", "ethusdt@ticker"],
          handler: self(),
          auto_connect: false
        })

      assert Process.alive?(pid)

      status = WebSocket.status(pid)
      assert status.connected == false
      assert status.futures == false
      assert "btcusdt@trade" in status.streams
      assert "ethusdt@ticker" in status.streams

      GenServer.stop(pid)
    end

    test "starts futures connection" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@markPrice"],
          handler: self(),
          futures: true,
          auto_connect: false
        })

      status = WebSocket.status(pid)
      assert status.futures == true
      assert "btcusdt@markPrice" in status.streams

      GenServer.stop(pid)
    end
  end

  describe "subscribe/2" do
    test "adds new streams" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@trade"],
          handler: self(),
          auto_connect: false
        })

      WebSocket.subscribe(pid, ["ethusdt@trade", "btcusdt@kline_1m"])
      :timer.sleep(50)

      status = WebSocket.status(pid)
      assert length(status.streams) == 3
      assert "ethusdt@trade" in status.streams
      assert "btcusdt@kline_1m" in status.streams

      GenServer.stop(pid)
    end

    test "deduplicates streams" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@trade"],
          handler: self(),
          auto_connect: false
        })

      WebSocket.subscribe(pid, ["btcusdt@trade"])
      :timer.sleep(50)

      status = WebSocket.status(pid)
      assert length(status.streams) == 1

      GenServer.stop(pid)
    end
  end

  describe "unsubscribe/2" do
    test "removes streams" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@trade", "ethusdt@ticker", "btcusdt@depth5"],
          handler: self(),
          auto_connect: false
        })

      WebSocket.unsubscribe(pid, ["ethusdt@ticker"])
      :timer.sleep(50)

      status = WebSocket.status(pid)
      assert length(status.streams) == 2
      refute "ethusdt@ticker" in status.streams

      GenServer.stop(pid)
    end
  end

  describe "reconnection" do
    test "handles ssl_closed by marking disconnected" do
      {:ok, pid} =
        WebSocket.start_link(%{
          streams: ["btcusdt@trade"],
          handler: self(),
          auto_connect: false
        })

      send(pid, {:ssl_closed, nil})
      :timer.sleep(50)

      status = WebSocket.status(pid)
      assert status.connected == false

      GenServer.stop(pid)
    end
  end
end
