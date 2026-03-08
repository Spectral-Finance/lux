defmodule Lux.Prisms.Coinbase.CreateOrderTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Coinbase.CreateOrder
  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "creates a market buy order" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["product_id"] == "BTC-USD"
        assert params["side"] == "BUY"
        assert params["order_configuration"]["market_market_ioc"]["quote_size"] == "100.00"

        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"success" => true, "order_id" => "order-123"}))
      end)

      assert {:ok, result} = CreateOrder.handler(%{product_id: "BTC-USD", side: "BUY", order_type: "market", amount: "100.00"}, %{name: "Test"})
      assert result.success == true
      assert result.order_id == "order-123"
    end

    test "creates a limit sell order" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["order_configuration"]["limit_limit_gtc"]["limit_price"] == "3000.00"

        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"success" => true, "order_id" => "order-456"}))
      end)

      assert {:ok, result} = CreateOrder.handler(%{product_id: "ETH-USD", side: "SELL", order_type: "limit", base_size: "1.0", limit_price: "3000.00"}, %{name: "Test"})
      assert result.order_id == "order-456"
    end

    test "handles order failure" do
      Req.Test.stub(Client, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"success" => false, "error_response" => %{"error" => "INSUFFICIENT_FUND", "message" => "Insufficient balance"}}))
      end)

      assert {:error, "Insufficient balance"} = CreateOrder.handler(%{product_id: "BTC-USD", side: "BUY", order_type: "market", amount: "999999"}, %{name: "Test"})
    end

    test "validates required parameters" do
      assert {:error, "Missing required parameter: product_id"} = CreateOrder.handler(%{side: "BUY", order_type: "market"}, %{name: "Test"})
    end
  end
end
