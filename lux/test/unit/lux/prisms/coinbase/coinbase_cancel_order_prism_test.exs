defmodule Lux.Prisms.Coinbase.CoinbaseCancelOrderPrismTest do
  use UnitCase, async: false

  alias Lux.Prisms.Coinbase.CoinbaseCancelOrderPrism
  alias Lux.Coinbase.Client

  @order_id "order-123"

  setup do
    Application.put_env(:lux, :coinbase_api_key, "test_api_key")
    Application.put_env(:lux, :coinbase_secret, "c2VjcmV0")
    Application.put_env(:lux, :coinbase_passphrase, "test_passphrase")
    Application.put_env(:lux, :coinbase_req_options, plug: {Req.Test, Lux.Coinbase.Client})
    :ok
  end

  describe "handler/2" do
    test "cancels an order by id (happy path / regression for issue #83)" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/orders/#{@order_id}"
        Req.Test.json(conn, %{"id" => @order_id})
      end)

      {:ok, %{status: "success", cancelled_order: cancelled}} =
        CoinbaseCancelOrderPrism.run(%{"order_id" => @order_id})

      assert cancelled["id"] == @order_id
    end

    test "cancels an order by client_oid" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.request_path == "/orders/client:client-abc"
        Req.Test.json(conn, %{"id" => "client-abc"})
      end)

      assert {:ok, %{status: "success"}} =
               CoinbaseCancelOrderPrism.run(%{"order_id" => "client:client-abc"})
    end
  end

  describe "null input" do
    test "rejects nil without crashing" do
      assert {:error, _reason} = CoinbaseCancelOrderPrism.run(nil)
    end

    test "rejects an empty map" do
      assert {:error, _reason} = CoinbaseCancelOrderPrism.run(%{})
    end
  end

  describe "empty input" do
    test "rejects an empty order_id" do
      assert {:error, _reason} = CoinbaseCancelOrderPrism.run(%{"order_id" => ""})
    end
  end

  describe "boundary limits" do
    test "rejects an order_id of only whitespace" do
      assert {:error, _reason} =
               CoinbaseCancelOrderPrism.run(%{"order_id" => "   "})
    end

    test "accepts a long order_id at the upper boundary" do
      long_id = String.duplicate("a", 10_000)

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        Req.Test.json(conn, %{"id" => long_id})
      end)

      assert {:ok, %{status: "success"}} =
               CoinbaseCancelOrderPrism.run(%{"order_id" => long_id})
    end
  end

  describe "negative / failure" do
    test "rejects a non-string order_id" do
      assert {:error, _reason} = CoinbaseCancelOrderPrism.run(%{"order_id" => 123})
    end

    test "refuses unauthorized calls with a typed error" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        conn = Plug.Conn.put_status(conn, 401)
        Req.Test.json(conn, %{"message" => "Unauthorized"})
      end)

      assert {:error, %{code: :unauthorized}} =
               CoinbaseCancelOrderPrism.run(%{"order_id" => @order_id})
    end

    test "is refused when credentials are not configured" do
      Application.delete_env(:lux, :coinbase_api_key)

      assert {:error, reason} = CoinbaseCancelOrderPrism.run(%{"order_id" => @order_id})
      assert String.contains?(reason, "coinbase_api_key")
    end
  end

  describe "concurrency" do
    test "concurrent cancels of the same order are atomic; the second is rejected" do
      :ets.new(:coinbase_concurrency_cancel, [:named_table, :public])
      :ets.insert(:coinbase_concurrency_cancel, {:calls, 0})

      Req.Test.expect(Lux.Coinbase.Client, 2, fn conn ->
        count = :ets.update_counter(:coinbase_concurrency_cancel, :calls, 1)

        if count == 1 do
          Req.Test.json(conn, %{"id" => @order_id})
        else
          conn = Plug.Conn.put_status(conn, 404)
          Req.Test.json(conn, %{"message" => "Not Found"})
        end
      end)

      results =
        [1, 2]
        |> Task.async_stream(fn _ ->
          CoinbaseCancelOrderPrism.run(%{"order_id" => @order_id})
        end)
        |> Enum.to_list()

      :ets.delete(:coinbase_concurrency_cancel)

      unwrapped =
        Enum.map(results, fn
          {:ok, result} -> result
          other -> other
        end)

      successes = Enum.count(unwrapped, fn
        {:ok, _} -> true
        _ -> false
      end)
      failures = Enum.count(unwrapped, fn
        {:error, _} -> true
        _ -> false
      end)
      not_found = Enum.count(unwrapped, fn
        {:error, %{"status" => 404}} -> true
        _ -> false
      end)

      assert successes == 1
      assert failures == 1
      assert not_found == 1
    end
  end
end
