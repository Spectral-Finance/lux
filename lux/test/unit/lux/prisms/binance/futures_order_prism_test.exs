defmodule Lux.Prisms.Binance.FuturesOrderPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.FuturesOrderPrism

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "handler/2 - market order" do
    test "successfully places a futures market order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/order"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 456789,
          "symbol" => "BTCUSDT",
          "side" => "BUY",
          "type" => "MARKET",
          "status" => "FILLED",
          "price" => "0",
          "origQty" => "0.001",
          "executedQty" => "0.001",
          "avgPrice" => "42000.00",
          "positionSide" => "BOTH",
          "reduceOnly" => false,
          "timeInForce" => "GTC",
          "updateTime" => 1234567890000
        }))
      end)

      assert {:ok, %{status: "success", order: order}} =
               FuturesOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "0.001",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 456789
      assert order.status == "FILLED"
      assert order.avg_price == "42000.00"
      assert order.position_side == "BOTH"
    end
  end

  describe "handler/2 - limit order with reduce_only" do
    test "successfully places a reduce-only limit order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 789012,
          "symbol" => "ETHUSDT",
          "side" => "SELL",
          "type" => "LIMIT",
          "status" => "NEW",
          "price" => "3500.00",
          "origQty" => "0.5",
          "executedQty" => "0.0",
          "avgPrice" => "0",
          "positionSide" => "BOTH",
          "reduceOnly" => true,
          "timeInForce" => "GTC",
          "updateTime" => 1234567890000
        }))
      end)

      assert {:ok, %{status: "success", order: order}} =
               FuturesOrderPrism.handler(
                 %{
                   symbol: "ETHUSDT",
                   side: "SELL",
                   type: "LIMIT",
                   quantity: "0.5",
                   price: "3500.00",
                   time_in_force: "GTC",
                   reduce_only: true,
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.reduce_only == true
      assert order.price == "3500.00"
    end
  end

  describe "handler/2 - stop market order" do
    test "successfully places a stop market order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 999999,
          "symbol" => "BTCUSDT",
          "side" => "SELL",
          "type" => "STOP_MARKET",
          "status" => "NEW",
          "price" => "0",
          "origQty" => "0.001",
          "executedQty" => "0.0",
          "avgPrice" => "0",
          "positionSide" => "BOTH",
          "reduceOnly" => true,
          "timeInForce" => "GTC",
          "updateTime" => 1234567890000
        }))
      end)

      assert {:ok, %{status: "success", order: order}} =
               FuturesOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "SELL",
                   type: "STOP_MARKET",
                   quantity: "0.001",
                   stop_price: "38000",
                   reduce_only: true,
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 999999
      assert order.type == "STOP_MARKET"
    end
  end

  describe "handler/2 - error handling" do
    test "handles insufficient margin error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -2019,
          "msg" => "Margin is insufficient."
        }))
      end)

      assert {:error, msg} =
               FuturesOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "100",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Insufficient margin"
    end

    test "handles quantity too small error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -4003,
          "msg" => "Quantity less than minimum."
        }))
      end)

      assert {:error, msg} =
               FuturesOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "0.0000001",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Quantity too small"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = FuturesOrderPrism.view()
      assert prism.input_schema.required == ["symbol", "side", "type"]
      assert Map.has_key?(prism.input_schema.properties, :reduce_only)
      assert Map.has_key?(prism.input_schema.properties, :position_side)
      assert Map.has_key?(prism.input_schema.properties, :stop_price)
    end

    test "validates output schema" do
      prism = FuturesOrderPrism.view()
      assert prism.output_schema.required == ["status", "order"]
    end
  end
end
