defmodule Lux.Prisms.Binance.Spot.PlaceOrderTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.Spot.PlaceOrder

  @agent_ctx %{name: "TradingAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "places a MARKET BUY order successfully" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/api/v3/order")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 12345,
          "symbol" => "BTCUSDT",
          "status" => "FILLED",
          "side" => "BUY",
          "type" => "MARKET",
          "executedQty" => "0.001",
          "transactTime" => 1_700_000_000_000
        }))
      end)

      assert {:ok, result} = PlaceOrder.handler(%{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "MARKET",
        quantity: "0.001",
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert result.order_id == 12345
      assert result.symbol == "BTCUSDT"
      assert result.status == "FILLED"
      assert result.executed_qty == "0.001"
    end

    test "places a LIMIT SELL order successfully" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 99999,
          "symbol" => "ETHUSDT",
          "status" => "NEW",
          "side" => "SELL",
          "type" => "LIMIT",
          "executedQty" => "0.00",
          "transactTime" => 1_700_000_000_001
        }))
      end)

      assert {:ok, result} = PlaceOrder.handler(%{
        symbol: "ETHUSDT",
        side: "SELL",
        type: "LIMIT",
        quantity: "0.5",
        price: "3000.00",
        time_in_force: "GTC",
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert result.order_id == 99999
      assert result.status == "NEW"
    end

    test "returns error for missing required parameter" do
      assert {:error, "Missing required parameter: symbol"} =
        PlaceOrder.handler(%{side: "BUY", type: "MARKET", quantity: "0.001"}, @agent_ctx)

      assert {:error, "Missing required parameter: side"} =
        PlaceOrder.handler(%{symbol: "BTCUSDT", type: "MARKET", quantity: "0.001"}, @agent_ctx)
    end

    test "handles Binance API rejection" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -2010,
          "msg" => "Account has insufficient balance for requested action."
        }))
      end)

      assert {:error, msg} = PlaceOrder.handler(%{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "MARKET",
        quantity: "999999",
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(msg, "insufficient balance")
    end
  end

  describe "schema validation" do
    test "input schema requires symbol, side, type, quantity" do
      prism = PlaceOrder.view()
      assert "symbol" in prism.input_schema.required
      assert "side" in prism.input_schema.required
      assert "type" in prism.input_schema.required
      assert "quantity" in prism.input_schema.required
    end

    test "output schema requires order_id, symbol, status" do
      prism = PlaceOrder.view()
      assert "order_id" in prism.output_schema.required
      assert "symbol" in prism.output_schema.required
      assert "status" in prism.output_schema.required
    end
  end
end
