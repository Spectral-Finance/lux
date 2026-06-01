defmodule Lux.Prisms.Binance.Spot.CancelOrderTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.Spot.CancelOrder

  @agent_ctx %{name: "TradingAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "cancels an order successfully" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert String.contains?(conn.request_path, "/api/v3/order")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 12345,
          "symbol" => "BTCUSDT",
          "status" => "CANCELED",
          "side" => "BUY",
          "type" => "LIMIT"
        }))
      end)

      assert {:ok, result} = CancelOrder.handler(%{
        symbol: "BTCUSDT",
        order_id: 12345,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert result.order_id == 12345
      assert result.symbol == "BTCUSDT"
      assert result.status == "CANCELED"
    end

    test "returns error for missing symbol" do
      assert {:error, "Missing or invalid symbol"} =
        CancelOrder.handler(%{order_id: 12345}, @agent_ctx)
    end

    test "returns error for missing order_id" do
      assert {:error, "Missing or invalid order_id"} =
        CancelOrder.handler(%{symbol: "BTCUSDT"}, @agent_ctx)
    end

    test "handles unknown order error" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -2011,
          "msg" => "Unknown order sent."
        }))
      end)

      assert {:error, msg} = CancelOrder.handler(%{
        symbol: "BTCUSDT",
        order_id: 99999,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(msg, "Unknown order")
    end
  end
end
