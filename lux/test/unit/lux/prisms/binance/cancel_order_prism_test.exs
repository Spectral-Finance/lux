defmodule Lux.Prisms.Binance.CancelOrderPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.CancelOrderPrism

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "handler/2 - cancel single spot order" do
    test "successfully cancels a spot order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/order"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 123456,
          "symbol" => "BTCUSDT",
          "status" => "CANCELED",
          "side" => "BUY",
          "type" => "LIMIT",
          "price" => "40000.00",
          "origQty" => "0.001"
        }))
      end)

      assert {:ok, %{status: "success", cancelled_order: order}} =
               CancelOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   order_id: 123456,
                   market: "spot",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 123456
      assert order.status == "CANCELED"
      assert order.symbol == "BTCUSDT"
    end
  end

  describe "handler/2 - cancel single futures order" do
    test "successfully cancels a futures order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/fapi/v1/order"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 789012,
          "symbol" => "ETHUSDT",
          "status" => "CANCELED",
          "side" => "SELL",
          "type" => "LIMIT",
          "price" => "3500.00",
          "origQty" => "1.0"
        }))
      end)

      assert {:ok, %{status: "success", cancelled_order: order}} =
               CancelOrderPrism.handler(
                 %{
                   symbol: "ETHUSDT",
                   order_id: 789012,
                   market: "futures",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 789012
      assert order.symbol == "ETHUSDT"
    end
  end

  describe "handler/2 - cancel all orders" do
    test "successfully cancels all open orders for a symbol" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/openOrders"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"orderId" => 111, "symbol" => "BTCUSDT", "status" => "CANCELED"},
          %{"orderId" => 222, "symbol" => "BTCUSDT", "status" => "CANCELED"}
        ]))
      end)

      assert {:ok, %{status: "success", cancelled_orders: orders}} =
               CancelOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   cancel_all: true,
                   market: "spot",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert length(orders) == 2
    end
  end

  describe "handler/2 - error handling" do
    test "handles order not found error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -2011,
          "msg" => "Unknown order sent."
        }))
      end)

      assert {:error, msg} =
               CancelOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   order_id: 999999,
                   market: "spot",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Order not found"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = CancelOrderPrism.view()
      assert prism.input_schema.required == ["symbol"]
      assert Map.has_key?(prism.input_schema.properties, :order_id)
      assert Map.has_key?(prism.input_schema.properties, :cancel_all)
      assert Map.has_key?(prism.input_schema.properties, :market)
    end

    test "validates output schema" do
      prism = CancelOrderPrism.view()
      assert prism.output_schema.required == ["status"]
    end
  end
end
