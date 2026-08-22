defmodule Lux.Lenses.Binance.ExchangeInfoLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Binance.ExchangeInfoLens

  setup do
    Req.Test.verify_on_exit!()
  end

  test "fetches Spot exchange info" do
    Req.Test.expect(Lux.Lenses.Binance.ExchangeInfoLensTest, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/v3/exchangeInfo"
      Req.Test.json(conn, %{"timezone" => "UTC", "symbols" => [%{"symbol" => "BTCUSDT", "status" => "TRADING"}]})
    end)

    opts = [req_options: [plug: {Req.Test, Lux.Lenses.Binance.ExchangeInfoLensTest}]]

    assert {:ok, %{"timezone" => "UTC", "symbols" => [%{"symbol" => "BTCUSDT"}]}} =
             ExchangeInfoLens.focus(%{market_type: "spot"}, opts)
  end

  test "fetches Futures exchange info" do
    Req.Test.expect(Lux.Lenses.Binance.ExchangeInfoLensTest, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/fapi/v1/exchangeInfo"
      Req.Test.json(conn, %{"timezone" => "UTC", "symbols" => [%{"symbol" => "ETHUSDT"}]})
    end)

    opts = [req_options: [plug: {Req.Test, Lux.Lenses.Binance.ExchangeInfoLensTest}]]

    assert {:ok, %{"timezone" => "UTC", "symbols" => [%{"symbol" => "ETHUSDT"}]}} =
             ExchangeInfoLens.focus(%{market_type: "futures"}, opts)
  end
end
