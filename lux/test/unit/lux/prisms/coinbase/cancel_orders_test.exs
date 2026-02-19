defmodule Lux.Prisms.Coinbase.CancelOrdersTest do
  @moduledoc """
  Test suite for the Coinbase CancelOrders prism.
  Tests cover:
  - Single order cancellation
  - Batch order cancellation
  - Partial failure handling
  - Input validation
  """

  use UnitAPICase, async: false

  alias Lux.Prisms.Coinbase.CancelOrders

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
    test "successfully cancels a single order" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/brokerage/orders/batch_cancel"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["order_ids"] == ["order-123"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "results" => [
            %{
              "order_id" => "order-123",
              "success" => true
            }
          ]
        }))
      end)

      assert {:ok, %{results: [result]}} =
               CancelOrders.handler(
                 %{
                   order_ids: ["order-123"],
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert result.order_id == "order-123"
      assert result.success == true
    end

    test "successfully cancels multiple orders" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["order_ids"]) == 3

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "results" => [
            %{"order_id" => "order-1", "success" => true},
            %{"order_id" => "order-2", "success" => true},
            %{"order_id" => "order-3", "success" => true}
          ]
        }))
      end)

      assert {:ok, %{results: results}} =
               CancelOrders.handler(
                 %{
                   order_ids: ["order-1", "order-2", "order-3"],
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      assert length(results) == 3
      assert Enum.all?(results, & &1.success)
    end

    test "handles partial failure in batch cancel" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "results" => [
            %{"order_id" => "order-1", "success" => true},
            %{"order_id" => "order-2", "success" => false, "failure_reason" => "UNKNOWN_ORDER"}
          ]
        }))
      end)

      assert {:ok, %{results: results}} =
               CancelOrders.handler(
                 %{
                   order_ids: ["order-1", "order-2"],
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )

      success = Enum.find(results, &(&1.order_id == "order-1"))
      assert success.success == true
      refute Map.has_key?(success, :failure_reason)

      failure = Enum.find(results, &(&1.order_id == "order-2"))
      assert failure.success == false
      assert failure.failure_reason == "UNKNOWN_ORDER"
    end

    test "handles API error" do
      Req.Test.expect(CoinbaseClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"message" => "Unauthorized"}))
      end)

      assert {:error, _} =
               CancelOrders.handler(
                 %{
                   order_ids: ["order-123"],
                   plug: {Req.Test, CoinbaseClientMock}
                 },
                 @agent_ctx
               )
    end

    test "validates order_ids is present" do
      assert {:error, "Missing order_ids"} =
               CancelOrders.handler(%{}, @agent_ctx)
    end

    test "validates order_ids is non-empty" do
      assert {:error, "order_ids must be a non-empty list"} =
               CancelOrders.handler(%{order_ids: []}, @agent_ctx)
    end

    test "validates order_ids are strings" do
      assert {:error, "All order_ids must be strings"} =
               CancelOrders.handler(%{order_ids: [123, 456]}, @agent_ctx)
    end
  end

  defp test_ec_private_key do
    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    pem_entry = :public_key.pem_entry_encode(:ECPrivateKey, ec_key)
    :public_key.pem_encode([pem_entry])
  end
end
