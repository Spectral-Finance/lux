defmodule Lux.Prisms.Coinbase.CoinbaseAccountsPrismTest do
  use UnitCase, async: false

  alias Lux.Prisms.Coinbase.CoinbaseAccountsPrism
  alias Lux.Coinbase.Client

  setup do
    Application.put_env(:lux, :coinbase_api_key, "test_api_key")
    Application.put_env(:lux, :coinbase_secret, "c2VjcmV0")
    Application.put_env(:lux, :coinbase_passphrase, "test_passphrase")
    Application.put_env(:lux, :coinbase_req_options, plug: {Req.Test, Lux.Coinbase.Client})
    :ok
  end

  describe "handler/2" do
    test "lists accounts (happy path / regression for issue #83)" do
      accounts = [
        %{"id" => "account-1", "currency" => "USD", "balance" => "1000.00", "available" => "1000.00"},
        %{"id" => "account-2", "currency" => "BTC", "balance" => "0.5", "available" => "0.4"}
      ]

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/accounts"
        Req.Test.json(conn, accounts)
      end)

      assert {:ok, %{status: "success", accounts: ^accounts}} =
               CoinbaseAccountsPrism.run(%{})
    end

    test "supports an optional limit" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert String.contains?(conn.query_string, "limit=1")
        Req.Test.json(conn, [])
      end)

      assert {:ok, %{status: "success"}} = CoinbaseAccountsPrism.run(%{"limit" => 1})
    end
  end

  describe "null input" do
    test "rejects nil without crashing" do
      assert {:error, _reason} = CoinbaseAccountsPrism.run(nil)
    end
  end

  describe "empty input" do
    test "accepts an empty map (lists all accounts)" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        Req.Test.json(conn, [])
      end)

      assert {:ok, %{status: "success"}} = CoinbaseAccountsPrism.run(%{})
    end
  end

  describe "boundary limits" do
    test "rejects a limit of zero (lower bound)" do
      assert {:error, _reason} = CoinbaseAccountsPrism.run(%{"limit" => 0})
    end

    test "accepts a limit of one (lower bound)" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        Req.Test.json(conn, [])
      end)

      assert {:ok, %{status: "success"}} = CoinbaseAccountsPrism.run(%{"limit" => 1})
    end
  end

  describe "negative / failure" do
    test "rejects a negative limit" do
      assert {:error, _reason} = CoinbaseAccountsPrism.run(%{"limit" => -1})
    end

    test "refuses unauthorized calls with a typed error" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        conn = Plug.Conn.put_status(conn, 401)
        Req.Test.json(conn, %{"message" => "Unauthorized"})
      end)

      assert {:error, %{code: :unauthorized}} = CoinbaseAccountsPrism.run(%{})
    end

    test "is refused when credentials are not configured" do
      Application.delete_env(:lux, :coinbase_api_key)

      assert {:error, reason} = CoinbaseAccountsPrism.run(%{})
      assert String.contains?(reason, "coinbase_api_key")
    end
  end
end
