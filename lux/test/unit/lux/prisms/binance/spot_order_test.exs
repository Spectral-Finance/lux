defmodule Lux.Prisms.Binance.SpotOrderTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Binance.SpotOrder

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "places limit order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v3/order"
      assert conn.query_string =~ "symbol=BTCUSDT"
      assert conn.query_string =~ "side=BUY"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 123456,
        "symbol" => "BTCUSDT",
        "status" => "NEW",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.000",
        "transactTime" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 123456, status: "NEW"}} =
      SpotOrder.handler(%{
        action: "place",
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: "0.001",
        price: "50000.00",
        time_in_force: "GTC",
        plug: {Req.Test, BinanceClientMock}, api_key: "test-key", secret_key: "test-secret"
      }, @agent_ctx)
  end

  test "places market order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.query_string =~ "type=MARKET"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 123457,
        "symbol" => "BTCUSDT",
        "status" => "FILLED",
        "side" => "SELL",
        "type" => "MARKET",
        "price" => "0.00",
        "origQty" => "0.001",
        "executedQty" => "0.001",
        "transactTime" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 123457, status: "FILLED"}} =
      SpotOrder.handler(%{action: "place", symbol: "BTCUSDT", side: "SELL", type: "MARKET", quantity: "0.001", plug: {Req.Test, BinanceClientMock}, api_key: "test-key", secret_key: "test-secret"}, @agent_ctx)
  end

  test "cancels order" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/api/v3/order"
      assert conn.query_string =~ "orderId=123456"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 123456,
        "symbol" => "BTCUSDT",
        "status" => "CANCELED",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.000"
      }))
    end)

    assert {:ok, %{order_id: 123456, status: "CANCELED"}} =
      SpotOrder.handler(%{action: "cancel", symbol: "BTCUSDT", order_id: 123456, plug: {Req.Test, BinanceClientMock}, api_key: "test-key", secret_key: "test-secret"}, @agent_ctx)
  end

  test "checks order status" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/v3/order"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "orderId" => 123456,
        "symbol" => "BTCUSDT",
        "status" => "FILLED",
        "side" => "BUY",
        "type" => "LIMIT",
        "price" => "50000.00",
        "origQty" => "0.001",
        "executedQty" => "0.001",
        "time" => 1609459200000
      }))
    end)

    assert {:ok, %{order_id: 123456, status: "FILLED"}} =
      SpotOrder.handler(%{action: "status", symbol: "BTCUSDT", order_id: 123456, plug: {Req.Test, BinanceClientMock}, api_key: "test-key", secret_key: "test-secret"}, @agent_ctx)
  end
end
