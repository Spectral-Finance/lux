defmodule Lux.Lenses.Binance.AccountInfoTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Binance.AccountInfo

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches spot balances" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.request_path == "/api/v3/account"
      assert conn.query_string =~ "timestamp="
      assert conn.query_string =~ "signature="

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "balances" => [
          %{"asset" => "BTC", "free" => "0.50000000", "locked" => "0.10000000"},
          %{"asset" => "DOGE", "free" => "0.00000000", "locked" => "0.00000000"}
        ]
      }))
    end)

    assert {:ok, %{balances: balances}} =
      AccountInfo.after_focus(%{endpoint: "balances", plug: {Req.Test, BinanceClientMock}})

    assert length(balances) == 1
    assert hd(balances).asset == "BTC"
  end

  test "fetches futures positions" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.request_path == "/fapi/v2/positionRisk"
      assert conn.query_string =~ "timestamp="

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!([
        %{
          "symbol" => "BTCUSDT",
          "positionAmt" => "0.001",
          "entryPrice" => "50000.00",
          "markPrice" => "51000.00",
          "unRealizedProfit" => "1.00",
          "leverage" => "10",
          "marginType" => "cross",
          "liquidationPrice" => "45000.00"
        },
        %{
          "symbol" => "ETHUSDT",
          "positionAmt" => "0",
          "entryPrice" => "0",
          "markPrice" => "2000.00",
          "unRealizedProfit" => "0",
          "leverage" => "20",
          "marginType" => "cross",
          "liquidationPrice" => "0"
        }
      ]))
    end)

    assert {:ok, %{positions: positions}} =
      AccountInfo.after_focus(%{endpoint: "positions", plug: {Req.Test, BinanceClientMock}})

    assert length(positions) == 1
    assert hd(positions).symbol == "BTCUSDT"
  end

  test "fetches futures account summary" do
    Req.Test.expect(BinanceClientMock, fn conn ->
      assert conn.request_path == "/fapi/v2/account"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "totalWalletBalance" => "10000.00000000",
        "totalUnrealizedProfit" => "150.00000000",
        "totalMarginBalance" => "10150.00000000",
        "availableBalance" => "8000.00000000",
        "maxWithdrawAmount" => "8000.00000000"
      }))
    end)

    assert {:ok, %{total_wallet_balance: "10000.00000000", available_balance: "8000.00000000"}} =
      AccountInfo.after_focus(%{endpoint: "futures_account", plug: {Req.Test, BinanceClientMock}})
  end

  test "returns error for unknown endpoint" do
    assert {:error, "Unknown endpoint: unknown"} =
      AccountInfo.after_focus(%{endpoint: "unknown", plug: {Req.Test, BinanceClientMock}})
  end
end
