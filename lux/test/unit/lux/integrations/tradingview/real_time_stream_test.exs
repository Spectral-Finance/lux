defmodule Lux.Integrations.TradingView.RealTimeStreamTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.TradingView.RealTimeStream

  describe "start_link/1" do
    test "starts with auto_connect: false" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT", "NASDAQ:AAPL"],
          handler: self(),
          auto_connect: false
        })

      assert Process.alive?(pid)

      status = RealTimeStream.status(pid)
      assert status.connected == false
      assert "BINANCE:BTCUSDT" in status.symbols
      assert "NASDAQ:AAPL" in status.symbols
      assert status.tracked_prices == 0

      GenServer.stop(pid)
    end
  end

  describe "add_symbols/2" do
    test "adds new symbols" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT"],
          handler: self(),
          auto_connect: false
        })

      RealTimeStream.add_symbols(pid, ["BINANCE:ETHUSDT", "NYSE:AAPL"])
      :timer.sleep(50)

      status = RealTimeStream.status(pid)
      assert length(status.symbols) == 3
      assert "BINANCE:ETHUSDT" in status.symbols

      GenServer.stop(pid)
    end

    test "deduplicates symbols" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT"],
          handler: self(),
          auto_connect: false
        })

      RealTimeStream.add_symbols(pid, ["BINANCE:BTCUSDT"])
      :timer.sleep(50)

      status = RealTimeStream.status(pid)
      assert length(status.symbols) == 1

      GenServer.stop(pid)
    end
  end

  describe "remove_symbols/2" do
    test "removes symbols" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT", "BINANCE:ETHUSDT", "NYSE:AAPL"],
          handler: self(),
          auto_connect: false
        })

      RealTimeStream.remove_symbols(pid, ["BINANCE:ETHUSDT"])
      :timer.sleep(50)

      status = RealTimeStream.status(pid)
      assert length(status.symbols) == 2
      refute "BINANCE:ETHUSDT" in status.symbols

      GenServer.stop(pid)
    end
  end

  describe "snapshot/1" do
    test "returns empty map when no data" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT"],
          handler: self(),
          auto_connect: false
        })

      assert %{} == RealTimeStream.snapshot(pid)

      GenServer.stop(pid)
    end
  end

  describe "reconnection" do
    test "handles ssl_closed" do
      {:ok, pid} =
        RealTimeStream.start_link(%{
          symbols: ["BINANCE:BTCUSDT"],
          handler: self(),
          auto_connect: false
        })

      send(pid, {:ssl_closed, nil})
      :timer.sleep(50)

      status = RealTimeStream.status(pid)
      assert status.connected == false

      GenServer.stop(pid)
    end
  end
end
