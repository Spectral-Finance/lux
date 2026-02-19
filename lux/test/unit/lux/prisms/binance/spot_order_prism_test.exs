defmodule Lux.Prisms.Binance.SpotOrderPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.SpotOrderPrism

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
    test "successfully places a market buy order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 123456,
          "symbol" => "BTCUSDT",
          "side" => "BUY",
          "type" => "MARKET",
          "status" => "FILLED",
          "price" => "0.00",
          "origQty" => "0.001",
          "executedQty" => "0.001",
          "timeInForce" => "GTC",
          "transactTime" => 1234567890000,
          "fills" => [
            %{
              "price" => "42000.00",
              "qty" => "0.001",
              "commission" => "0.00000075",
              "commissionAsset" => "BTC"
            }
          ]
        }))
      end)

      assert {:ok, %{status: "success", order: order}} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "0.001",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 123456
      assert order.symbol == "BTCUSDT"
      assert order.side == "BUY"
      assert order.type == "MARKET"
      assert order.status == "FILLED"
      assert order.executed_qty == "0.001"
      assert length(order.fills) == 1
    end
  end

  describe "handler/2 - limit order" do
    test "successfully places a limit sell order" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 789012,
          "symbol" => "ETHUSDT",
          "side" => "SELL",
          "type" => "LIMIT",
          "status" => "NEW",
          "price" => "3500.00",
          "origQty" => "1.0",
          "executedQty" => "0.0",
          "timeInForce" => "GTC",
          "transactTime" => 1234567890000,
          "fills" => []
        }))
      end)

      assert {:ok, %{status: "success", order: order}} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "ETHUSDT",
                   side: "SELL",
                   type: "LIMIT",
                   quantity: "1.0",
                   price: "3500.00",
                   time_in_force: "GTC",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert order.order_id == 789012
      assert order.status == "NEW"
      assert order.price == "3500.00"
      assert order.time_in_force == "GTC"
    end
  end

  describe "handler/2 - error handling" do
    test "handles insufficient balance error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -2010,
          "msg" => "Account has insufficient balance for requested action."
        }))
      end)

      assert {:error, msg} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "100",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Insufficient balance"
    end

    test "handles invalid symbol error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -1121,
          "msg" => "Invalid symbol."
        }))
      end)

      assert {:error, msg} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "INVALID",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "1",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Invalid symbol"
    end

    test "handles rate limiting" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "code" => -1015,
          "msg" => "Too many requests"
        }))
      end)

      assert {:error, msg} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "0.001",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Rate limited"
    end

    test "handles generic API error" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -1100,
          "msg" => "Illegal characters found in parameter."
        }))
      end)

      assert {:error, msg} =
               SpotOrderPrism.handler(
                 %{
                   symbol: "BTCUSDT",
                   side: "BUY",
                   type: "MARKET",
                   quantity: "0.001",
                   plug: {Req.Test, Lux.Integrations.Binance.Client}
                 },
                 @agent_ctx
               )

      assert msg =~ "Binance API error"
      assert msg =~ "-1100"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SpotOrderPrism.view()
      assert prism.input_schema.required == ["symbol", "side", "type"]
      assert Map.has_key?(prism.input_schema.properties, :symbol)
      assert Map.has_key?(prism.input_schema.properties, :side)
      assert Map.has_key?(prism.input_schema.properties, :type)
      assert Map.has_key?(prism.input_schema.properties, :quantity)
      assert Map.has_key?(prism.input_schema.properties, :price)
    end

    test "validates output schema" do
      prism = SpotOrderPrism.view()
      assert prism.output_schema.required == ["status", "order"]
    end
  end
end
