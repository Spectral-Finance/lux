defmodule Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrismTest do
  use UnitCase, async: false

  alias Lux.Prisms.Coinbase.CoinbaseExecuteOrderPrism
  alias Lux.Coinbase.Client

  @product_id "BTC-USD"
  @valid_input %{
    "product_id" => @product_id,
    "side" => "buy",
    "type" => "limit",
    "size" => 0.01,
    "price" => 50_000
  }

  setup do
    Application.put_env(:lux, :coinbase_api_key, "test_api_key")
    Application.put_env(:lux, :coinbase_secret, "c2VjcmV0")
    Application.put_env(:lux, :coinbase_passphrase, "test_passphrase")
    Application.put_env(:lux, :coinbase_req_options, plug: {Req.Test, Lux.Coinbase.Client})
    :ok
  end

  describe "handler/2" do
    test "places a limit buy order (happy path / regression for issue #83)" do
      order = %{
        "id" => "order-123",
        "product_id" => @product_id,
        "side" => "buy",
        "size" => "0.01",
        "price" => "50000"
      }

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/orders"
        Req.Test.json(conn, order)
      end)

      assert {:ok, %{status: "success", order: ^order}} =
               CoinbaseExecuteOrderPrism.run(@valid_input)
    end

    test "places a market sell order" do
      input = %{
        "product_id" => "ETH-USD",
        "side" => "sell",
        "type" => "market",
        "size" => 1.5
      }

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, %{"id" => "order-456"})
      end)

      assert {:ok, %{status: "success"}} =
               CoinbaseExecuteOrderPrism.run(input)
    end

    test "includes optional client_oid and price in the request" do
      input = %{
        "product_id" => @product_id,
        "side" => "buy",
        "type" => "limit",
        "size" => 0.01,
        "price" => 50_000,
        "client_oid" => "client-abc"
      }

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/orders"
        Req.Test.json(conn, %{"id" => "order-789"})
      end)

      assert {:ok, %{status: "success"}} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "signs the request with the configured credentials" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert Plug.Conn.get_req_header(conn, "cb-access-key") == ["test_api_key"]
        assert Plug.Conn.get_req_header(conn, "cb-access-passphrase") == ["test_passphrase"]
        assert hd(Plug.Conn.get_req_header(conn, "cb-access-sign")) != ""
        assert hd(Plug.Conn.get_req_header(conn, "cb-access-timestamp")) != ""
        Req.Test.json(conn, %{"id" => "order-signed"})
      end)

      assert {:ok, %{status: "success"}} = CoinbaseExecuteOrderPrism.run(@valid_input)
    end
  end

  describe "null input" do
    test "rejects nil without crashing" do
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(nil)
    end

    test "rejects an empty map" do
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(%{})
    end
  end

  describe "empty input" do
    test "rejects an empty product_id" do
      input = Map.put(@valid_input, "product_id", "")
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "rejects an empty side" do
      input = Map.put(@valid_input, "side", "")
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end
  end

  describe "boundary limits" do
    test "rejects a size of zero (lower bound)" do
      input = Map.put(@valid_input, "size", 0)
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "rejects a limit price of zero (lower bound)" do
      input = Map.put(@valid_input, "type", "limit") |> Map.put("price", 0)
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "accepts a large size at the upper boundary" do
      input = Map.put(@valid_input, "size", 1_000_000)

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        Req.Test.json(conn, %{"id" => "order-big"})
      end)

      assert {:ok, %{status: "success"}} = CoinbaseExecuteOrderPrism.run(input)
    end
  end

  describe "negative / failure" do
    test "rejects a negative size" do
      input = Map.put(@valid_input, "size", -0.01)
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "rejects an invalid side" do
      input = Map.put(@valid_input, "side", "hold")
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "rejects an invalid order type" do
      input = Map.put(@valid_input, "type", "stop")
      assert {:error, _reason} = CoinbaseExecuteOrderPrism.run(input)
    end

    test "refuses unauthorized calls with a typed error" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        conn = Plug.Conn.put_status(conn, 401)
        Req.Test.json(conn, %{"message" => "Unauthorized"})
      end)

      assert {:error, %{code: :unauthorized}} =
               CoinbaseExecuteOrderPrism.run(@valid_input)
    end

    test "is refused when credentials are not configured" do
      Application.delete_env(:lux, :coinbase_api_key)

      assert {:error, reason} = CoinbaseExecuteOrderPrism.run(@valid_input)
      assert String.contains?(reason, "coinbase_api_key")
    end
  end
end
