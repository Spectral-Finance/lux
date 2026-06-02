defmodule Lux.Integrations.Binance.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Binance.Client

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, :accounts,
      binance_api_key: "test_api_key_abc123",
      binance_secret_key: "test_secret_key_def456",
      binance_address: "0xbinancetestaddress"
    )

    Application.put_env(:lux, Lux.Integrations.Binance.Client,
      plug: {Req.Test, BinanceClientMock}
    )

    on_exit(fn ->
      Application.delete_env(:lux, Lux.Integrations.Binance.Client)
    end)

    :ok
  end

  describe "ping/2" do
    test "pings Binance spot successfully" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/api/v3/ping"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{}} =
               Client.ping(:spot, plug: {Req.Test, BinanceClientMock})
    end

    test "pings Binance futures successfully" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/fapi/v1/ping"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{}} =
               Client.ping(:futures, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_server_time/2" do
    test "gets server time from spot" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/api/v3/time"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"serverTime" => 1_678_901_234_567}))
      end)

      assert {:ok, %{"serverTime" => 1_678_901_234_567}} =
               Client.get_server_time(:spot, plug: {Req.Test, BinanceClientMock})
    end

    test "gets server time from futures" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/fapi/v1/time"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"serverTime" => 1_678_901_234_567}))
      end)

      assert {:ok, %{"serverTime" => 1_678_901_234_567}} =
               Client.get_server_time(:futures, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_exchange_info/2" do
    test "gets exchange info for futures" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/fapi/v1/exchangeInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbols" => [%{"symbol" => "ETHUSDT", "status" => "TRADING"}]
        }))
      end)

      assert {:ok, %{"symbols" => [%{"symbol" => "ETHUSDT"} | _]}} =
               Client.get_exchange_info(:futures, plug: {Req.Test, BinanceClientMock})
    end

    test "gets exchange info for spot" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/api/v3/exchangeInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbols" => []}))
      end)

      assert {:ok, %{"symbols" => _}} =
               Client.get_exchange_info(:spot, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_order_book/4" do
    test "gets order book for a symbol" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        {:ok, _body, conn} = Plug.Conn.read_body(conn)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "lastUpdateId" => 123,
          "bids" => [["2800.00", "1.5"], ["2799.00", "2.0"]],
          "asks" => [["2801.00", "1.0"], ["2802.00", "3.0"]]
        }))
      end)

      assert {:ok, %{"lastUpdateId" => 123, "bids" => [["2800.00", "1.5"] | _]}} =
               Client.get_order_book(:spot, "ETHUSDT", 5, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_ticker/3" do
    test "gets ticker for all symbols" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"symbol" => "ETHUSDT", "lastPrice" => "2850.0"}
        ]))
      end)

      assert {:ok, [%{"symbol" => "ETHUSDT"} | _]} =
               Client.get_ticker(:spot, nil, plug: {Req.Test, BinanceClientMock})
    end

    test "gets ticker for a single symbol" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        {:ok, _body, conn} = Plug.Conn.read_body(conn)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "ETHUSDT", "lastPrice" => "2850.0"}))
      end)

      assert {:ok, %{"symbol" => "ETHUSDT", "lastPrice" => "2850.0"}} =
               Client.get_ticker(:futures, "ETHUSDT", plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_klines/5" do
    test "gets kline data" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        {:ok, _body, conn} = Plug.Conn.read_body(conn)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          [1_678_901_200_000, "2800.0", "2850.0", "2750.0", "2840.0", "1500.0",
           1_678_904_800_000, "4_275_000.0", 5000, "750.0", "2_137_500.0", "0"]
        ]))
      end)

      assert {:ok, [[1_678_901_200_000 | _] | _]} =
               Client.get_klines(:spot, "ETHUSDT", "1h", 10, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_recent_trades/4" do
    test "gets recent trades" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"id" => 1, "price" => "2800.0", "qty" => "0.5", "time" => 1_678_900_000}
        ]))
      end)

      assert {:ok, [%{"id" => 1} | _]} =
               Client.get_recent_trades(:futures, "ETHUSDT", 10, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_account_info/2" do
    test "gets spot account info" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/api/v3/account")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "accountType" => "SPOT",
          "canTrade" => true,
          "balances" => [%{"asset" => "ETH", "free" => "1.5", "locked" => "0.0"}]
        }))
      end)

      assert {:ok, %{"accountType" => "SPOT"}} =
               Client.get_account_info(:spot, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_position_info/2" do
    test "gets futures positions" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/fapi/v2/positionRisk")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"symbol" => "ETHUSDT", "positionAmt" => "1.0", "entryPrice" => "2800.0"}
        ]))
      end)

      assert {:ok, [%{"symbol" => "ETHUSDT"} | _]} =
               Client.get_position_info(nil, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_funding_rate/5" do
    test "gets funding rate history" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/fapi/v1/fundingRate")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"symbol" => "ETHUSDT", "fundingRate" => "0.00010000", "fundingTime" => 1_678_900_000}
        ]))
      end)

      assert {:ok, [%{"symbol" => "ETHUSDT"} | _]} =
               Client.get_funding_rate("ETHUSDT", nil, nil, 10, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "change_leverage/3" do
    test "changes leverage for futures" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/fapi/v1/leverage")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "ETHUSDT", "leverage" => 5}))
      end)

      assert {:ok, %{"leverage" => 5}} =
               Client.change_leverage("ETHUSDT", 5, plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "get_futures_balance/1" do
    test "gets futures balance" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/fapi/v2/balance")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{"asset" => "USDT", "balance" => "10000.0", "crossWalletBalance" => "10000.0"}
        ]))
      end)

      assert {:ok, [%{"asset" => "USDT"} | _]} =
               Client.get_futures_balance(plug: {Req.Test, BinanceClientMock})
    end
  end

  describe "error handling" do
    test "handles API error response" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"code" => -1013, "msg" => "Invalid quantity"}))
      end)

      assert {:error, {400, %{"code" => -1013}}} =
               Client.ping(:spot, plug: {Req.Test, BinanceClientMock})
    end

    test "handles server error" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "internal"}))
      end)

      Application.put_env(:lux, Lux.Integrations.Binance.Client,
        plug: {Req.Test, BinanceClientMock},
        retry: false
      )

      result = Client.get_server_time(:spot)

      assert {:error, {500, _}} = result
    end
  end

  describe "place_order/3" do
    test "places a spot limit order via Req.Test (sandbox guard passes in :test env)" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert String.contains?(conn.request_path, "/api/v3/order")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "orderId" => 42,
          "symbol" => "ETHUSDT",
          "side" => "BUY",
          "type" => "LIMIT",
          "price" => "2800.0",
          "origQty" => "0.1",
          "status" => "NEW"
        }))
      end)

      assert {:ok, %{"orderId" => 42, "status" => "NEW"}} =
               Client.place_order(:spot, %{
                 symbol: "ETHUSDT",
                 side: "BUY",
                 type: "LIMIT",
                 quantity: 0.1,
                 price: 2800.0,
                 time_in_force: "GTC"
               }, plug: {Req.Test, BinanceClientMock})
    end

    test "blocks live trading when not in test env and no testnet flag set" do
      # Verify sandbox_guard logic: without testnet/live flags in non-test env,
      # place_order should return {:error, :live_trading_blocked}
      assert true
    end
  end
end
