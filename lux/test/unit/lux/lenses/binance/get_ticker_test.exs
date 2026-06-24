defmodule Lux.Lenses.Binance.Spot.GetTickerTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Binance.Spot.GetTicker

  describe "focus/2" do
    test "successfully fetches ticker price" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.request_path == "/api/v3/ticker/price?symbol=BTCUSDT"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "BTCUSDT",
          "price" => "50000.00"
        }))
      end)

      assert {:ok, %{"symbol" => "BTCUSDT", "price" => "50000.00"}} =
        GetTicker.focus(%{symbol: "BTCUSDT"})
    end

    test "handles missing symbol error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"code" => -1121, "msg" => "Invalid symbol"}))
      end)

      assert {:ok, %{"code" => -1121}} = GetTicker.focus(%{symbol: "INVALID"})
    end
  end
end
