defmodule Lux.Lenses.Binance.TickerPriceLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Binance.TickerPriceLens

  setup do
    Req.Test.verify_on_exit!()
  end

  test "fetches Spot ticker price for symbol" do
    Req.Test.expect(Lux.Lenses.Binance.TickerPriceLensTest, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/v3/ticker/price"
      assert conn.query_string =~ "symbol=BTCUSDT"
      Req.Test.json(conn, %{"symbol" => "BTCUSDT", "price" => "95120.50"})
    end)

    opts = [req_options: [plug: {Req.Test, Lux.Lenses.Binance.TickerPriceLensTest}]]

    assert {:ok, %{"symbol" => "BTCUSDT", "price" => "95120.50"}} =
             TickerPriceLens.focus(%{market_type: "spot", symbol: "BTCUSDT"}, opts)
  end

  test "fetches Futures ticker price for symbol" do
    Req.Test.expect(Lux.Lenses.Binance.TickerPriceLensTest, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/fapi/v1/ticker/price"
      assert conn.query_string =~ "symbol=ETHUSDT"
      Req.Test.json(conn, %{"symbol" => "ETHUSDT", "price" => "3500.00"})
    end)

    opts = [req_options: [plug: {Req.Test, Lux.Lenses.Binance.TickerPriceLensTest}]]

    assert {:ok, %{"symbol" => "ETHUSDT", "price" => "3500.00"}} =
             TickerPriceLens.focus(%{market_type: "futures", symbol: "ETHUSDT"}, opts)
  end
end
