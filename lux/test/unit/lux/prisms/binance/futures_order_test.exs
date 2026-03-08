defmodule Lux.Prisms.Binance.FuturesOrderTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Binance.FuturesOrder

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "places futures limit order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/fapi/v1/order"
      assert conn.query_string =~ "symbol=BTCUSDT"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 789012,
        "symbol" => "BTCUSDT",
        "status" => "NEW",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.000",
        "positionSide" => "BOTH",
        "updateTime" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 789012, status: "NEW"}} =
      FuturesOrder.handler(%{action: "place", symbol: "BTCUSDT", side: "BUY", type: "LIMIT", quantity: "0.001", price: "50000.00", time_in_force: "GTC", plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "places stop market order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.query_string =~ "type=STOP_MARKET"
      assert conn.query_string =~ "stopPrice=48000.00"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 789013,
        "symbol" => "BTCUSDT",
        "status" => "NEW",
        "side" => "SELL",
        "type" => "STOP_MARKET",
        "price" => "0.00",
        "origQty" => "0.001",
        "executedQty" => "0.000",
        "positionSide" => "BOTH",
        "updateTime" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 789013, status: "NEW"}} =
      FuturesOrder.handler(%{action: "place", symbol: "BTCUSDT", side: "SELL", type: "STOP_MARKET", quantity: "0.001", stop_price: "48000.00", plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "cancels futures order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/fapi/v1/order"
      assert conn.query_string =~ "orderId=789012"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 789012,
        "symbol" => "BTCUSDT",
        "status" => "CANCELED",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.000",
        "positionSide" => "BOTH"
      }))
    end)

    assert {:ok, %{order_id: 789012, status: "CANCELED"}} =
      FuturesOrder.handler(%{action: "cancel", symbol: "BTCUSDT", order_id: 789012, plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "sets leverage" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/fapi/v1/leverage"
      assert conn.query_string =~ "leverage=20"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "BTCUSDT", "leverage" => 20, "maxNotionalValue" => "1000000"}))
    end)

    assert {:ok, %{symbol: "BTCUSDT", leverage: 20}} =
      FuturesOrder.handler(%{action: "set_leverage", symbol: "BTCUSDT", leverage: 20, plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "sets margin type" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/fapi/v1/marginType"
      assert conn.query_string =~ "marginType=ISOLATED"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"msg" => "success"}))
    end)

    assert {:ok, %{symbol: "BTCUSDT", margin_type: "ISOLATED"}} =
      FuturesOrder.handler(%{action: "set_margin_type", symbol: "BTCUSDT", margin_type: "ISOLATED", plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "checks futures order status" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/fapi/v1/order"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 789012,
        "symbol" => "BTCUSDT",
        "status" => "FILLED",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.001",
        "positionSide" => "BOTH",
        "updateTime" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 789012, status: "FILLED"}} =
      FuturesOrder.handler(%{action: "status", symbol: "BTCUSDT", order_id: 789012, plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end

  test "handles unknown action" do
    assert {:error, "Unknown action: invalid"} =
      FuturesOrder.handler(%{action: "invalid", symbol: "BTCUSDT", plug: {Req.Test, BinanceClientMock}}, @agent_ctx)
  end
end
