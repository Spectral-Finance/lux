defmodule Lux.Unit.Lenses.TradingView.PriceDataLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.PriceDataLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "view/0" do
    test "returns lens configuration" do
      lens = PriceDataLens.view()

      assert lens.name == "TradingView.PriceData"
      assert lens.url == "https://api.binance.com/api/v3/klines"
      assert lens.method == :get
    end

    test "has correct schema" do
      lens = PriceDataLens.view()

      assert is_map(lens.schema)
      assert lens.schema[:type] == :object
      assert Map.has_key?(lens.schema[:properties], :symbol)
      assert Map.has_key?(lens.schema[:properties], :interval)
      assert Map.has_key?(lens.schema[:properties], :limit)
      assert Map.has_key?(lens.schema[:properties], :endpoint)
    end
  end

  describe "before_focus/1" do
    test "sets klines endpoint by default" do
      params = %{symbol: "BTCUSDT", interval: "1h", limit: 100, endpoint: "klines"}
      result = PriceDataLens.before_focus(params)

      assert result[:url] == "https://api.binance.com/api/v3/klines"
      assert result[:params][:symbol] == "BTCUSDT"
      assert result[:params][:interval] == "1h"
      assert result[:params][:limit] == 100
    end

    test "sets ticker endpoint" do
      params = %{symbol: "BTCUSDT", endpoint: "ticker"}
      result = PriceDataLens.before_focus(params)

      assert result[:url] == "https://api.binance.com/api/v3/ticker/price"
    end

    test "sets 24h ticker endpoint" do
      params = %{symbol: "BTCUSDT", endpoint: "ticker24h"}
      result = PriceDataLens.before_focus(params)

      assert result[:url] == "https://api.binance.com/api/v3/ticker/24hr"
    end

    test "caps limit at 1000" do
      params = %{symbol: "BTCUSDT", interval: "1h", limit: 5000, endpoint: "klines"}
      result = PriceDataLens.before_focus(params)

      assert result[:params][:limit] == 1000
    end
  end

  describe "after_focus/1" do
    test "parses kline list response" do
      response = [
        [1700000000000, "50000.00", "50100.00", "49900.00", "50050.00", "100.5"],
        [1700003600000, "50050.00", "50200.00", "50000.00", "50150.00", "120.3"]
      ]

      assert {:ok, %{result: klines, type: :klines}} = PriceDataLens.after_focus(response)

      assert length(klines) == 2
      assert hd(klines)[:open] == 50000.00
      assert hd(klines)[:close] == 50050.00
    end

    test "parses single ticker response" do
      response = %{"symbol" => "BTCUSDT", "price" => "67500.00"}

      assert {:ok, %{result: ticker, type: :ticker}} = PriceDataLens.after_focus(response)

      assert ticker[:symbol] == "BTCUSDT"
      assert ticker[:price] == 67500.00
    end

    test "parses 24h ticker response" do
      response = %{
        "symbol" => "BTCUSDT",
        "lastPrice" => "67500.00",
        "highPrice" => "68000.00",
        "lowPrice" => "66000.00",
        "volume" => "15000.00",
        "quoteVolume" => "1000000000.00",
        "priceChange" => "1500.00",
        "priceChangePercent" => "2.27"
      }

      assert {:ok, %{result: ticker, type: :ticker_24h}} = PriceDataLens.after_focus(response)

      assert ticker[:symbol] == "BTCUSDT"
      assert ticker[:last_price] == 67500.00
      assert ticker[:price_change_percent] == 2.27
    end

    test "handles API error response" do
      response = %{"code" => -1121, "msg" => "Invalid symbol"}

      assert {:error, %{code: -1121, message: "Invalid symbol"}} =
               PriceDataLens.after_focus(response)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "data"}

      assert {:error, error_msg} = PriceDataLens.after_focus(response)
      assert is_binary(error_msg)
    end
  end

  describe "focus/1 with mocked API" do
    test "fetches kline data successfully" do
      mock_klines = [
        [1700000000000, "50000.00", "50100.00", "49900.00", "50050.00", "100.5"]
      ]

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["symbol"] == "BTCUSDT"
        assert conn.params["interval"] == "1h"
        Req.Test.json(conn, mock_klines)
      end)

      assert {:ok, %{result: klines, type: :klines}} =
               PriceDataLens.focus(%{symbol: "BTCUSDT", interval: "1h", limit: 1})

      assert length(klines) == 1
      assert hd(klines)[:close] == 50050.00
    end

    test "fetches ticker price successfully" do
      mock_ticker = %{"symbol" => "BTCUSDT", "price" => "67500.00"}

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["symbol"] == "BTCUSDT"
        Req.Test.json(conn, mock_ticker)
      end)

      assert {:ok, %{result: ticker, type: :ticker}} =
               PriceDataLens.focus(%{symbol: "BTCUSDT", endpoint: "ticker"})

      assert ticker[:price] == 67500.00
    end
  end
end
