defmodule Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrismTest do
  use UnitCase, async: false

  alias Lux.Prisms.Coinbase.CoinbaseOpenOrdersPrism
  alias Lux.Coinbase.Client

  setup do
    Application.put_env(:lux, :coinbase_api_key, "test_api_key")
    Application.put_env(:lux, :coinbase_secret, "c2VjcmV0")
    Application.put_env(:lux, :coinbase_passphrase, "test_passphrase")
    Application.put_env(:lux, :coinbase_req_options, plug: {Req.Test, Lux.Coinbase.Client})
    :ok
  end

  describe "handler/2" do
    test "lists open orders (happy path / regression for issue #83)" do
      orders = [%{"id" => "order-1", "product_id" => "BTC-USD", "status" => "open"}]

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/orders"
        assert String.contains?(conn.query_string, "status=open")
        Req.Test.json(conn, orders)
      end)

      assert {:ok, %{status: "success", orders: ^orders}} =
               CoinbaseOpenOrdersPrism.run(%{})
    end

    test "filters by product_id and status" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert String.contains?(conn.query_string, "product_id=ETH-USD")
        assert String.contains?(conn.query_string, "status=open")
        Req.Test.json(conn, [])
      end)

      assert {:ok, %{status: "success"}} =
               CoinbaseOpenOrdersPrism.run(%{"product_id" => "ETH-USD", "status" => "open"})
    end
  end

  describe "null input" do
    test "rejects nil without crashing" do
      assert {:error, _reason} = CoinbaseOpenOrdersPrism.run(nil)
    end

    test "accepts an empty map (defaults to open orders)" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        Req.Test.json(conn, [])
      end)

      assert {:ok, %{status: "success"}} = CoinbaseOpenOrdersPrism.run(%{})
    end
  end

  describe "empty input" do
    test "rejects a status that is not a string" do
      assert {:error, _reason} = CoinbaseOpenOrdersPrism.run(%{"status" => :open})
    end
  end

  describe "boundary limits" do
    test "accepts each valid status boundary value" do
      for status <- ["open", "pending", "active"] do
        Req.Test.expect(Lux.Coinbase.Client, fn conn ->
          Req.Test.json(conn, [])
        end)

        assert {:ok, %{status: "success"}} =
                 CoinbaseOpenOrdersPrism.run(%{"status" => status})
      end
    end

    test "rejects an out-of-range status" do
      assert {:error, _reason} = CoinbaseOpenOrdersPrism.run(%{"status" => "filled"})
    end
  end

  describe "negative / failure" do
    test "refuses unauthorized calls with a typed error" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        conn = Plug.Conn.put_status(conn, 401)
        Req.Test.json(conn, %{"message" => "Unauthorized"})
      end)

      assert {:error, %{code: :unauthorized}} =
               CoinbaseOpenOrdersPrism.run(%{})
    end

    test "is refused when credentials are not configured" do
      Application.delete_env(:lux, :coinbase_api_key)

      assert {:error, reason} = CoinbaseOpenOrdersPrism.run(%{})
      assert String.contains?(reason, "coinbase_api_key")
    end
  end
end
