defmodule Lux.Integrations.Hyperliquid.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid.Client

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    :ok
  end

  describe "query_public/2" do
    test "fetches all mid prices" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/info"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"type" => "allMids"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ETH" => "2800.0", "BTC" => "62000.0"}))
      end)

      assert {:ok, %{"ETH" => "2800.0", "BTC" => "62000.0"}} =
               Client.query_public(%{type: "allMids"}, plug: {Req.Test, HyperliquidClientMock})
    end

    test "fetches metadata" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"type" => "meta"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"universe" => [%{"name" => "ETH"}]}))
      end)

      assert {:ok, %{"universe" => [%{"name" => "ETH"}]}} =
               Client.get_market_data(plug: {Req.Test, HyperliquidClientMock})
    end

    test "fetches L2 order book" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"type" => "l2Book", "req" => %{"coin" => "ETH"}}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "levels" => [["2799.0", "10.0"], ["2800.0", "5.0"]]
        }))
      end)

      assert {:ok, %{"levels" => _}} =
               Client.get_l2_book("ETH", plug: {Req.Test, HyperliquidClientMock})
    end

    test "fetches open orders for address" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["type"] == "openOrders"
        assert decoded["user"] == "0xuser123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} =
               Client.get_open_orders("0xuser123", plug: {Req.Test, HyperliquidClientMock})
    end

    test "handles API error response" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "internal"}))
      end)

      assert {:error, {500, %{"error" => "internal"}}} =
               Client.query_public(%{type: "allMids"}, plug: {Req.Test, HyperliquidClientMock})
    end

    test "handles network error" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "connection refused"}))
      end)

      assert {:error, {500, _}} =
               Client.query_public(%{type: "allMids"}, plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "place_order/2" do
    test "places a limit order successfully" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        assert conn.request_path == "/exchange"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "order"
        assert hd(decoded["action"]["orders"])["a"] == "ETH"
        assert hd(decoded["action"]["orders"])["b"] == true
        assert hd(decoded["action"]["orders"])["s"] == "0.1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "response" => %{
            "data" => %{
              "statuses" => [%{"resting" => %{"oid" => 42, "status" => "open"}}]
            }
          }
        }))
      end)

      assert {:ok, %{"resting" => %{"oid" => 42, "status" => "open"}}} =
               Client.place_order(
                 %{
                   asset: "ETH",
                   is_buy: true,
                   size: 0.1,
                   price: 2800.0,
                   order_type: %{limit: %{tif: "Gtc"}},
                   reduce_only: false
                 },
                 plug: {Req.Test, HyperliquidClientMock}
               )
    end

    test "handles order error" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "response" => %{
            "data" => %{
              "statuses" => [%{"error" => "Insufficient margin"}]
            }
          }
        }))
      end)

      assert {:error, "Insufficient margin"} =
               Client.place_order(
                 %{asset: "ETH", is_buy: true, size: 0.1, price: 2800.0},
                 plug: {Req.Test, HyperliquidClientMock}
               )
    end
  end

  describe "cancel_order/3" do
    test "cancels an order successfully" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        assert conn.request_path == "/exchange"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "cancel"
        assert hd(decoded["action"]["cancels"])["a"] == "ETH"
        assert hd(decoded["action"]["cancels"])["o"] == 123_456

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "response" => %{
            "data" => %{
              "statuses" => [%{"status" => "cancelled"}]
            }
          }
        }))
      end)

      assert {:ok, %{"status" => "cancelled"}} =
               Client.cancel_order("ETH", 123_456, plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "modify_margin/3" do
    test "modifies leverage for a position" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["isCross"] == true
        assert decoded["action"]["leverage"] == 5

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      params = %{leverage: 5, is_cross: true}
      assert {:ok, %{"status" => "ok"}} =
               Client.modify_margin("ETH", params, plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "get_account_info/2" do
    test "fetches account info" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["type"] == "clearinghouseState"
        assert decoded["user"] == "0xuser123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"crossMarginSummary" => %{"accountValue" => "10000.0"}}))
      end)

      assert {:ok, %{"crossMarginSummary" => %{"accountValue" => "10000.0"}}} =
               Client.get_account_info("0xuser123", plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "get_recent_trades/2" do
    test "fetches recent trades for an asset" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "recentTrades"
        assert decoded["req"]["coin"] == "ETH"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{"coin" => "ETH", "side" => "B", "px" => "2800.0", "sz" => "1.0"}]))
      end)

      assert {:ok, [%{"coin" => "ETH"} | _]} =
               Client.get_recent_trades("ETH", plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "get_candles/5" do
    test "fetches candle data" do
      start_time = 1_700_000_000_000
      end_time = 1_700_003_600_000

      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "candleSnapshot"
        assert decoded["req"]["coin"] == "ETH"
        assert decoded["req"]["interval"] == "1h"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{"t" => start_time, "o" => "2800.0"}]))
      end)

      assert {:ok, [%{"t" => ^start_time} | _]} =
               Client.get_candles("ETH", "1h", start_time, end_time, plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "get_funding_history/3" do
    test "fetches funding history" do
      start_time = 1_700_000_000_000

      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "fundingHistory"
        assert decoded["req"]["coin"] == "ETH"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([%{"fundingRate" => "0.0000125"}]))
      end)

      assert {:ok, [%{"fundingRate" => "0.0000125"} | _]} =
               Client.get_funding_history("ETH", start_time, plug: {Req.Test, HyperliquidClientMock})
    end
  end

  describe "sandbox guard" do
    test "blocks private actions when live trading is disabled" do
      # Temporarily disable the global bypass
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, false)

      try do
        assert {:error, :live_trading_disabled} =
                 Client.place_order(%{
                   asset: "ETH",
                   is_buy: true,
                   size: 0.1,
                   price: 2800.0
                 })

        assert {:error, :live_trading_disabled} =
                 Client.cancel_order("ETH", 123_456)

        assert {:error, :live_trading_disabled} =
                 Client.modify_margin("ETH", %{is_deposit: true, amount: "100"})

        assert {:error, :live_trading_disabled} =
                 Client.query_private(%{type: "order", orders: [], grouping: "na"})
      after
        Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      end
    end

    test "public queries are not blocked by sandbox guard" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, false)

      try do
        Req.Test.expect(HyperliquidClientMock, fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ETH" => "2800.0"}))
        end)

        assert {:ok, _} = Client.query_public(%{type: "allMids"}, plug: {Req.Test, HyperliquidClientMock})
      after
        Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      end
    end
  end

  describe "order precision" do
    test "rounds price to 5 decimal places" do
      assert Client.round_price(2800.123456) == "2800.12346"
      assert Client.round_price(2800.0) == "2800.0"
      assert Client.round_price(0.00001) == "0.00001"
    end

    test "rounds size to 5 decimal places" do
      assert Client.round_size("ETH", 0.12345678) == "0.12346"
      assert Client.round_size("BTC", 0.1) == "0.1"
    end

    test "builds order with rounded price and size" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        order = hd(decoded["action"]["orders"])
        assert order["p"] == "2800.12346"
        assert order["s"] == "0.12346"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "response" => %{
            "data" => %{
              "statuses" => [%{"resting" => %{"oid" => 1, "status" => "open"}}]
            }
          }
        }))
      end)

      assert {:ok, _} =
               Client.place_order(
                 %{
                   asset: "ETH",
                   is_buy: true,
                   size: 0.12345678,
                   price: 2800.123456,
                   order_type: %{limit: %{tif: "Gtc"}}
                 },
                 plug: {Req.Test, HyperliquidClientMock}
               )
    end

    test "rounds trigger price in trigger orders" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        order = hd(decoded["action"]["orders"])
        assert order["t"]["trigger"]["triggerPx"] == "2500.11111"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "response" => %{
            "data" => %{
              "statuses" => [%{"resting" => %{"oid" => 2, "status" => "open"}}]
            }
          }
        }))
      end)

      assert {:ok, _} =
               Client.place_order(
                 %{
                   asset: "ETH",
                   is_buy: false,
                   size: 0.5,
                   price: 2500.111111,
                   order_type: %{trigger: %{trigger_px: 2500.111111, is_market: true, tpsl: "sl"}},
                   reduce_only: true
                 },
                 plug: {Req.Test, HyperliquidClientMock}
               )
    end
  end

  describe "margin payload correctness" do
    test "adds margin with correct updateIsolatedMargin action" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["isBuy"] == true
        assert decoded["action"]["ntli"] == "100"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok", "hash" => "0xabc"}))
      end)

      assert {:ok, _} =
               Client.modify_margin("ETH", %{is_deposit: true, amount: "100"},
                 plug: {Req.Test, HyperliquidClientMock})
    end

    test "removes margin with correct updateIsolatedMargin action" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["isBuy"] == false
        assert decoded["action"]["ntli"] == "50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok", "hash" => "0xdef"}))
      end)

      assert {:ok, _} =
               Client.modify_margin("ETH", %{is_deposit: false, amount: "50"},
                 plug: {Req.Test, HyperliquidClientMock})
    end

    test "updates leverage with correct updateLeverage action" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateLeverage"
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["isCross"] == true
        assert decoded["action"]["leverage"] == 5

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} =
               Client.modify_margin("ETH", %{leverage: 5, is_cross: true},
                 plug: {Req.Test, HyperliquidClientMock})
    end

    test "changes margin mode with correct updateLeverage action" do
      Req.Test.expect(HyperliquidClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateLeverage"
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["isCross"] == false
        # Defaults to leverage 1 when no leverage specified (safe default)
        assert decoded["action"]["leverage"] == 1

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} =
               Client.modify_margin("ETH", %{is_cross: false, mode: "isolated"},
                 plug: {Req.Test, HyperliquidClientMock})
    end
  end
end
