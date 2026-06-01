defmodule Lux.Prisms.Binance.Account.GetAccountTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Binance.Account.GetAccount

  @agent_ctx %{name: "PortfolioAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  @mock_account %{
    "canTrade" => true,
    "canWithdraw" => true,
    "canDeposit" => true,
    "accountType" => "SPOT",
    "balances" => [
      %{"asset" => "BTC", "free" => "0.05000000", "locked" => "0.01000000"},
      %{"asset" => "USDT", "free" => "1500.00000000", "locked" => "0.00000000"},
      %{"asset" => "ADA", "free" => "0.00000000", "locked" => "0.00000000"}
    ]
  }

  describe "handler/2" do
    test "fetches account info and filters zero balances by default" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, "/api/v3/account")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(@mock_account))
      end)

      assert {:ok, result} = GetAccount.handler(%{
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert result.can_trade == true
      assert result.can_withdraw == true
      assert result.account_type == "SPOT"

      # ADA with zero balance should be filtered out
      asset_names = Enum.map(result.balances, & &1.asset)
      assert "BTC" in asset_names
      assert "USDT" in asset_names
      refute "ADA" in asset_names
    end

    test "returns all balances when all_balances: true" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(@mock_account))
      end)

      assert {:ok, result} = GetAccount.handler(%{
        all_balances: true,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert length(result.balances) == 3
    end

    test "handles unauthorized error" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "code" => -2015,
          "msg" => "Invalid API-key, IP, or permissions for action."
        }))
      end)

      assert {:error, msg} = GetAccount.handler(%{
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert String.contains?(msg, "Unauthorized")
    end
  end
end
