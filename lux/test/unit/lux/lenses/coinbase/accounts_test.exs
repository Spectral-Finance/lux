defmodule Lux.Lenses.Coinbase.AccountsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.Accounts
  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "list_accounts/2" do
    test "returns formatted accounts" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/accounts"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"accounts" => [
          %{"uuid" => "abc-123", "name" => "BTC Wallet", "currency" => "BTC",
            "available_balance" => %{"value" => "1.5", "currency" => "BTC"},
            "hold" => %{"value" => "0.1", "currency" => "BTC"},
            "default" => true, "active" => true, "type" => "ACCOUNT_TYPE_CRYPTO"}
        ]}))
      end)

      assert {:ok, accounts} = Accounts.list_accounts()
      assert length(accounts) == 1
      assert hd(accounts).uuid == "abc-123"
      assert hd(accounts).available_balance.value == "1.5"
    end
  end

  describe "get_account/2" do
    test "returns a specific account" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/accounts/abc-123"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"account" => %{
          "uuid" => "abc-123", "name" => "BTC Wallet", "currency" => "BTC",
          "available_balance" => %{"value" => "1.5", "currency" => "BTC"},
          "hold" => %{"value" => "0", "currency" => "BTC"},
          "default" => true, "active" => true, "type" => "ACCOUNT_TYPE_CRYPTO"
        }}))
      end)

      assert {:ok, account} = Accounts.get_account("abc-123")
      assert account.uuid == "abc-123"
    end

    test "handles not found" do
      Req.Test.stub(Client, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "NOT_FOUND", "message" => "Account not found"}))
      end)

      assert {:error, {400, "NOT_FOUND: Account not found"}} = Accounts.get_account("nonexistent")
    end
  end

  describe "list_portfolios/1" do
    test "returns formatted portfolios" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/portfolios"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"portfolios" => [
          %{"uuid" => "port-1", "name" => "Default", "type" => "DEFAULT", "deleted" => false}
        ]}))
      end)

      assert {:ok, portfolios} = Accounts.list_portfolios()
      assert hd(portfolios).name == "Default"
    end
  end
end
