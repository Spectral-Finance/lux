defmodule Lux.Lenses.Binance.MarketDataLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.MarketDataLens

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys,
      binance_api_key: "test-api-key",
      binance_secret_key: "test-secret-key"
    )
    :ok
  end

  describe "focus/2 - ticker_price" do
    test "successfully fetches ticker price" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/ticker/price"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "BTCUSDT",
          "price" => "42000.00"
        }))
      end)

      assert {:ok, %{symbol: "BTCUSDT", price: "42000.00"}} =
               MarketDataLens.focus(%{type: "ticker_price", symbol: "BTCUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end
  end

  describe "focus/2 - ticker_24h" do
    test "successfully fetches 24h ticker stats" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/ticker/24hr"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "ETHUSDT",
          "priceChange" => "-50.00",
          "priceChangePercent" => "-1.5",
          "weightedAvgPrice" => "3300.00",
          "lastPrice" => "3250.00",
          "volume" => "100000.00",
          "quoteVolume" => "330000000.00",
          "openPrice" => "3300.00",
          "highPrice" => "3400.00",
          "lowPrice" => "3200.00",
          "count" => 500000
        }))
      end)

      assert {:ok, result} =
               MarketDataLens.focus(%{type: "ticker_24h", symbol: "ETHUSDT"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert result.symbol == "ETHUSDT"
      assert result.price_change == "-50.00"
      assert result.last_price == "3250.00"
      assert result.volume == "100000.00"
      assert result.high_price == "3400.00"
      assert result.low_price == "3200.00"
    end
  end

  describe "focus/2 - depth" do
    test "successfully fetches order book depth" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/depth"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "lastUpdateId" => 123456789,
          "bids" => [["42000.00", "0.5"], ["41999.00", "1.0"]],
          "asks" => [["42001.00", "0.3"], ["42002.00", "0.8"]]
        }))
      end)

      assert {:ok, result} =
               MarketDataLens.focus(%{type: "depth", symbol: "BTCUSDT", limit: 5},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert length(result.bids) == 2
      assert length(result.asks) == 2
      assert result.last_update_id == 123456789
    end
  end

  describe "focus/2 - recent_trades" do
    test "successfully fetches recent trades" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/trades"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => 1,
            "price" => "42000.00",
            "qty" => "0.01",
            "time" => 1234567890000,
            "isBuyerMaker" => false
          },
          %{
            "id" => 2,
            "price" => "42001.00",
            "qty" => "0.02",
            "time" => 1234567890001,
            "isBuyerMaker" => true
          }
        ]))
      end)

      assert {:ok, %{trades: trades}} =
               MarketDataLens.focus(%{type: "recent_trades", symbol: "BTCUSDT", limit: 10},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert length(trades) == 2
      assert hd(trades).price == "42000.00"
      assert hd(trades).is_buyer_maker == false
    end
  end

  describe "focus/2 - klines" do
    test "successfully fetches klines" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/klines"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          [1234567890000, "42000", "42500", "41800", "42200", "100", 1234567899999, "4200000", 500]
        ]))
      end)

      assert {:ok, %{klines: klines}} =
               MarketDataLens.focus(%{type: "klines", symbol: "BTCUSDT", interval: "1h", limit: 10},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )

      assert length(klines) == 1
      [kline] = klines
      assert kline.open == "42000"
      assert kline.high == "42500"
      assert kline.low == "41800"
      assert kline.close == "42200"
      assert kline.volume == "100"
    end
  end

  describe "focus/2 - futures endpoint" do
    test "uses futures API path when endpoint is futures" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        assert conn.request_path == "/fapi/v1/ticker/price"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "symbol" => "BTCUSDT",
          "price" => "42000.00"
        }))
      end)

      assert {:ok, _} =
               MarketDataLens.focus(%{type: "ticker_price", symbol: "BTCUSDT", endpoint: "futures"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end
  end

  describe "focus/2 - error handling" do
    test "returns error for unknown market data type" do
      assert {:error, "Unknown market data type: invalid_type"} =
               MarketDataLens.focus(%{type: "invalid_type", symbol: "BTCUSDT"})
    end

    test "propagates API errors" do
      Req.Test.expect(Lux.Integrations.Binance.Client, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => -1121,
          "msg" => "Invalid symbol."
        }))
      end)

      assert {:error, _} =
               MarketDataLens.focus(%{type: "ticker_price", symbol: "INVALID"},
                 plug: {Req.Test, Lux.Integrations.Binance.Client}
               )
    end
  end
end
