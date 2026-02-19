defmodule Lux.Prisms.Coinbase.CreateOrderTest do
  @moduledoc """
  Test suite for the Coinbase CreateOrder prism.
  Tests cover:
  - Market order creation
  - Limit order creation
  - Stop-limit order creation
  - Error handling
  - Input validation
  """

  use UnitAPICase, async: false

  alias Lux.Prisms.Coinbase.CreateOrder

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
    test "successfully creates a market buy order" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/brokerage/orders"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["product_id"] == "BTC-USD"
        assert decoded["side"] == "BUY"
        assert decoded["order_configuration"]["market_market_ioc"]["quote_size"] == "100.00"
        assert is_binary(decoded["client_order_id"])

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => true,
          "order_id" => "market-order-123",
          "success_response" => %{
            "order_id" => "market-order-123",
            "product_id" => "BTC-USD",
            "side" => "BUY"
          }
        }))
      end)

      assert {:ok, result} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "BUY",
                   order_configuration: %{
                     market_market_ioc: %{quote_size: "100.00"}
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.success == true
      assert result.order_id == "market-order-123"
      assert result.product_id == "BTC-USD"
      assert result.side == "BUY"
      assert is_binary(result.client_order_id)
    end

    test "successfully creates a limit GTC order" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["order_configuration"]["limit_limit_gtc"]["base_size"] == "0.001"
        assert decoded["order_configuration"]["limit_limit_gtc"]["limit_price"] == "40000.00"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => true,
          "order_id" => "limit-order-456"
        }))
      end)

      assert {:ok, result} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "BUY",
                   order_configuration: %{
                     limit_limit_gtc: %{
                       base_size: "0.001",
                       limit_price: "40000.00"
                     }
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.success == true
      assert result.order_id == "limit-order-456"
    end

    test "successfully creates a stop-limit GTC order" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        stop_config = decoded["order_configuration"]["stop_limit_stop_limit_gtc"]
        assert stop_config["base_size"] == "0.001"
        assert stop_config["limit_price"] == "39000.00"
        assert stop_config["stop_price"] == "39500.00"
        assert stop_config["stop_direction"] == "STOP_DIRECTION_STOP_DOWN"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => true,
          "order_id" => "stop-order-789"
        }))
      end)

      assert {:ok, result} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "SELL",
                   order_configuration: %{
                     stop_limit_stop_limit_gtc: %{
                       base_size: "0.001",
                       limit_price: "39000.00",
                       stop_price: "39500.00",
                       stop_direction: "STOP_DIRECTION_STOP_DOWN"
                     }
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.success == true
      assert result.order_id == "stop-order-789"
    end

    test "uses provided client_order_id" do
      custom_id = "my-custom-order-id-123"

      Req.Test.expect(CoinbaseClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["client_order_id"] == custom_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => true,
          "order_id" => "custom-order-001"
        }))
      end)

      assert {:ok, result} =
               CreateOrder.handler(
                 %{
                   client_order_id: custom_id,
                   product_id: "BTC-USD",
                   side: "BUY",
                   order_configuration: %{
                     market_market_ioc: %{quote_size: "50.00"}
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.client_order_id == custom_id
    end

    test "handles order creation failure" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "success" => false,
          "failure_reason" => "INSUFFICIENT_FUNDS",
          "order_id" => ""
        }))
      end)

      assert {:error, "INSUFFICIENT_FUNDS"} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "BUY",
                   order_configuration: %{
                     market_market_ioc: %{quote_size: "1000000.00"}
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles API error" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => "INVALID_REQUEST",
          "message" => "Invalid product_id"
        }))
      end)

      assert {:error, _} =
               CreateOrder.handler(
                 %{
                   product_id: "INVALID-PAIR",
                   side: "BUY",
                   order_configuration: %{
                     market_market_ioc: %{quote_size: "100.00"}
                   },
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )
    end

    test "validates required product_id" do
      assert {:error, "Missing or invalid product_id"} =
               CreateOrder.handler(
                 %{
                   side: "BUY",
                   order_configuration: %{market_market_ioc: %{quote_size: "100"}}
                 },
                 @agent_ctx
               )
    end

    test "validates required side" do
      assert {:error, "Missing or invalid side"} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   order_configuration: %{market_market_ioc: %{quote_size: "100"}}
                 },
                 @agent_ctx
               )
    end

    test "validates order_configuration presence" do
      assert {:error, "Missing order_configuration"} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "BUY"
                 },
                 @agent_ctx
               )
    end

    test "validates order_configuration type" do
      assert {:error, msg} =
               CreateOrder.handler(
                 %{
                   product_id: "BTC-USD",
                   side: "BUY",
                   order_configuration: %{invalid_type: %{}}
                 },
                 @agent_ctx
               )

      assert msg =~ "Invalid order configuration"
    end
  end

  defp test_ec_private_key do
    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    pem_entry = :public_key.pem_entry_encode(:ECPrivateKey, ec_key)
    :public_key.pem_encode([pem_entry])
  end
end
