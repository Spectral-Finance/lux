defmodule Lux.Lenses.Binance.MarketDataTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Binance.MarketData

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches ticker price" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.query_string =~ "symbol=BTCUSDT"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "BTCUSDT", "price" => "50000.00"}))
    end)

    assert {:ok, %{symbol: "BTCUSDT", price: "50000.00"}} =
      MarketData.after_focus(%{endpoint: "ticker", symbol: "BTCUSDT", plug: {Req.Test, BinanceClientMock}})
  end

  test "fetches order book" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.query_string =~ "symbol=BTCUSDT"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "lastUpdateId" => 1,
        "bids" => [["50000.00", "1.5"], ["49999.00", "2.0"]],
        "asks" => [["50001.00", "0.5"], ["50002.00", "1.0"]]
      }))
    end)

    assert {:ok, %{bids: bids, asks: asks}} =
      MarketData.after_focus(%{endpoint: "depth", symbol: "BTCUSDT", limit: 10, plug: {Req.Test, BinanceClientMock}})

    assert length(bids) == 2
    assert length(asks) == 2
  end

  test "fetches klines" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.query_string =~ "interval=1h"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!([
        [1609459200000, "29000.00", "29500.00", "28800.00", "29300.00", "1000.0", 1609462800000, "29150000.00"],
        [1609462800000, "29300.00", "29600.00", "29100.00", "29400.00", "800.0", 1609466400000, "23520000.00"]
      ]))
    end)

    assert {:ok, %{klines: klines}} =
      MarketData.after_focus(%{endpoint: "klines", symbol: "BTCUSDT", interval: "1h", limit: 2, plug: {Req.Test, BinanceClientMock}})

    assert length(klines) == 2
  end

  test "fetches 24h ticker stats" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "symbol" => "ETHUSDT",
        "priceChange" => "50.00",
        "priceChangePercent" => "2.50",
        "weightedAvgPrice" => "2050.00",
        "lastPrice" => "2050.00",
        "volume" => "50000.00",
        "quoteVolume" => "102500000.00",
        "openPrice" => "2000.00",
        "highPrice" => "2100.00",
        "lowPrice" => "1980.00"
      }))
    end)

    assert {:ok, %{symbol: "ETHUSDT", price_change_percent: "2.50"}} =
      MarketData.after_focus(%{endpoint: "ticker_24h", symbol: "ETHUSDT", plug: {Req.Test, BinanceClientMock}})
  end

  test "handles API errors" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(400, Jason.encode!(%{"msg" => "Invalid symbol."}))
    end)

    assert {:error, {400, "Invalid symbol."}} =
      MarketData.after_focus(%{endpoint: "ticker", symbol: "INVALID", plug: {Req.Test, BinanceClientMock}})
  end
end
