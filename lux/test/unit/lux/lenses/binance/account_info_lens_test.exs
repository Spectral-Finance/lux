defmodule Lux.Lenses.Binance.AccountInfoLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.AccountInfoLens

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "focus/2 - spot_account" do
    test "successfully fetches spot account with non-zero balances" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/account"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "accountType" => "SPOT",
          "canTrade" => true,
          "canWithdraw" => true,
          "canDeposit" => true,
          "balances" => [
            %{"asset" => "BTC", "free" => "0.001", "locked" => "0.0"},
            %{"asset" => "ETH", "free" => "1.5", "locked" => "0.5"},
            %{"asset" => "USDT", "free" => "0.0", "locked" => "0.0"},
            %{"asset" => "SOL", "free" => "10.0", "locked" => "0.0"}
          ]
        }))
      end)

      assert {:ok, result} =
               AccountInfoLens.focus(%{type: "spot_account"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert result.account_type == "SPOT"
      assert result.can_trade == true
      # Only non-zero balances should be returned (BTC, ETH, SOL)
      assert length(result.balances) == 3
      assert Enum.any?(result.balances, &(&1.asset == "BTC"))
      assert Enum.any?(result.balances, &(&1.asset == "ETH"))
      refute Enum.any?(result.balances, &(&1.asset == "USDT"))
    end
  end

  describe "focus/2 - futures_account" do
    test "successfully fetches futures account with active positions" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/fapi/v2/account"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "totalWalletBalance" => "10000.00",
          "totalUnrealizedProfit" => "150.00",
          "totalMarginBalance" => "10150.00",
          "availableBalance" => "8000.00",
          "positions" => [
            %{
              "symbol" => "BTCUSDT",
              "positionAmt" => "0.1",
              "entryPrice" => "40000.00",
              "unrealizedProfit" => "200.00",
              "leverage" => "10",
              "marginType" => "cross",
              "liquidationPrice" => "36000.00"
            },
            %{
              "symbol" => "ETHUSDT",
              "positionAmt" => "0",
              "entryPrice" => "0",
              "unrealizedProfit" => "0",
              "leverage" => "20",
              "marginType" => "cross",
              "liquidationPrice" => "0"
            }
          ]
        }))
      end)

      assert {:ok, result} =
               AccountInfoLens.focus(%{type: "futures_account"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert result.total_wallet_balance == "10000.00"
      assert result.available_balance == "8000.00"
      # Only active positions (non-zero amount)
      assert length(result.positions) == 1
      assert hd(result.positions).symbol == "BTCUSDT"
      assert hd(result.positions).leverage == "10"
    end
  end

  describe "focus/2 - open_orders" do
    test "successfully fetches open orders" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/openOrders"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "orderId" => 123456,
            "symbol" => "BTCUSDT",
            "side" => "BUY",
            "type" => "LIMIT",
            "price" => "40000.00",
            "origQty" => "0.001",
            "executedQty" => "0.0",
            "status" => "NEW",
            "timeInForce" => "GTC",
            "time" => 1234567890000
          }
        ]))
      end)

      assert {:ok, %{orders: orders}} =
               AccountInfoLens.focus(%{type: "open_orders", symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert length(orders) == 1
      order = hd(orders)
      assert order.order_id == 123456
      assert order.symbol == "BTCUSDT"
      assert order.side == "BUY"
      assert order.status == "NEW"
    end
  end

  describe "focus/2 - trade_history" do
    test "successfully fetches trade history" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/myTrades"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => 1,
            "orderId" => 100,
            "symbol" => "BTCUSDT",
            "price" => "42000.00",
            "qty" => "0.001",
            "commission" => "0.00042",
            "commissionAsset" => "USDT",
            "time" => 1234567890000,
            "isBuyer" => true,
            "isMaker" => false
          }
        ]))
      end)

      assert {:ok, %{trades: trades}} =
               AccountInfoLens.focus(%{type: "trade_history", symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert length(trades) == 1
      trade = hd(trades)
      assert trade.symbol == "BTCUSDT"
      assert trade.price == "42000.00"
      assert trade.is_buyer == true
    end
  end

  describe "focus/2 - futures_positions" do
    test "successfully fetches active futures positions" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/fapi/v2/positionRisk"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "symbol" => "BTCUSDT",
            "positionAmt" => "0.1",
            "entryPrice" => "40000.00",
            "markPrice" => "42000.00",
            "unRealizedProfit" => "200.00",
            "liquidationPrice" => "36000.00",
            "leverage" => "10",
            "marginType" => "cross",
            "notional" => "4200.00"
          },
          %{
            "symbol" => "ETHUSDT",
            "positionAmt" => "0",
            "entryPrice" => "0",
            "markPrice" => "3000.00",
            "unRealizedProfit" => "0",
            "liquidationPrice" => "0",
            "leverage" => "20",
            "marginType" => "cross",
            "notional" => "0"
          }
        ]))
      end)

      assert {:ok, %{positions: positions}} =
               AccountInfoLens.focus(%{type: "futures_positions"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      # Only non-zero positions
      assert length(positions) == 1
      pos = hd(positions)
      assert pos.symbol == "BTCUSDT"
      assert pos.entry_price == "40000.00"
      assert pos.mark_price == "42000.00"
    end
  end

  describe "focus/2 - error handling" do
    test "returns error for unknown type" do
      assert {:error, "Unknown account data type: invalid"} =
               AccountInfoLens.focus(%{type: "invalid"})
    end

    test "propagates API errors" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "code" => -2015,
          "msg" => "Invalid API-key, IP, or permissions for action."
        }))
      end)

      assert {:error, _} =
               AccountInfoLens.focus(%{type: "spot_account"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end
  end
end
