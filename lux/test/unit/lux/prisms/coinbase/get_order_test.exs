defmodule Lux.Prisms.Coinbase.GetOrderTest do
  @moduledoc """
  Test suite for the Coinbase GetOrder prism.
  Tests cover:
  - Successfully retrieving an order
  - Error handling
  - Input validation
  """

  use UnitAPICase, async: false

  alias Lux.Prisms.Coinbase.GetOrder

  @agent_ctx %{agent: %{name: "TestTradingAgent"}}

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, :api_keys,
      Keyword.merge(
        Application.get_env(:lux, :api_keys, []),
        [
          coinbase_api_key: "organizations/test-org/apiKeys/test-key-id",
          coinbase_api_secret: test_ec_private_key()
        ]
      )
    )

    :ok
  end

  describe "handler/2" do
    test "successfully retrieves an order" do
      order_id = "test-order-abc-123"

      Req.Test.expect(CoinbaseClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/brokerage/orders/historical/#{order_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "order" => %{
            "order_id" => order_id,
            "product_id" => "BTC-USD",
            "side" => "BUY",
            "status" => "FILLED",
            "order_type" => "LIMIT",
            "created_time" => "2024-01-01T00:00:00Z",
            "completion_percentage" => "100",
            "filled_size" => "0.001",
            "filled_value" => "43.25",
            "average_filled_price" => "43250.00",
            "total_fees" => "0.26",
            "total_value_after_fees" => "43.51",
            "order_configuration" => %{
              "limit_limit_gtc" => %{
                "base_size" => "0.001",
                "limit_price" => "43250.00"
              }
            },
            "settled" => true,
            "cancel_message" => nil
          }
        }))
      end)

      assert {:ok, result} =
               GetOrder.handler(
                 %{
                   order_id: order_id,
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.order_id == order_id
      assert result.product_id == "BTC-USD"
      assert result.side == "BUY"
      assert result.status == "FILLED"
      assert result.order_type == "LIMIT"
      assert result.filled_size == "0.001"
      assert result.average_filled_price == "43250.00"
      assert result.total_fees == "0.26"
      assert result.settled == true
    end

    test "handles order not found" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => "NOT_FOUND",
          "message" => "Order not found"
        }))
      end)

      assert {:error, _} =
               GetOrder.handler(
                 %{
                   order_id: "nonexistent-order",
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )
    end

    test "validates order_id is present" do
      assert {:error, "Missing or invalid order_id"} =
               GetOrder.handler(%{}, @agent_ctx)
    end

    test "validates order_id is not empty" do
      assert {:error, "Missing or invalid order_id"} =
               GetOrder.handler(%{order_id: ""}, @agent_ctx)
    end
  end

  defp test_ec_private_key do
    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    pem_entry = :public_key.pem_entry_encode(:ECPrivateKey, ec_key)
    :public_key.pem_encode([pem_entry])
  end
end
