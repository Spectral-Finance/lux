defmodule Lux.Integrations.TradingViewTest do
  use UnitCase, async: true

  alias Lux.Integrations.TradingView

  describe "scanner_url/1" do
    test "returns correct URL for valid screeners" do
      assert TradingView.scanner_url("america") ==
               "https://scanner.tradingview.com/america/scan"

      assert TradingView.scanner_url("crypto") ==
               "https://scanner.tradingview.com/crypto/scan"

      assert TradingView.scanner_url("forex") ==
               "https://scanner.tradingview.com/forex/scan"
    end

    test "raises for invalid screener" do
      assert_raise ArgumentError, ~r/Invalid screener/, fn ->
        TradingView.scanner_url("invalid")
      end
    end
  end

  describe "interval_suffix/1" do
    test "returns empty string for daily interval" do
      assert TradingView.interval_suffix("1d") == ""
    end

    test "returns correct suffix for minute intervals" do
      assert TradingView.interval_suffix("1m") == "|1"
      assert TradingView.interval_suffix("5m") == "|5"
      assert TradingView.interval_suffix("15m") == "|15"
      assert TradingView.interval_suffix("30m") == "|30"
    end

    test "returns correct suffix for hour intervals" do
      assert TradingView.interval_suffix("1h") == "|60"
      assert TradingView.interval_suffix("2h") == "|120"
      assert TradingView.interval_suffix("4h") == "|240"
    end

    test "returns correct suffix for weekly and monthly" do
      assert TradingView.interval_suffix("1W") == "|1W"
      assert TradingView.interval_suffix("1M") == "|1M"
    end

    test "raises for invalid interval" do
      assert_raise ArgumentError, ~r/Invalid interval/, fn ->
        TradingView.interval_suffix("3h")
      end
    end
  end

  describe "column_with_interval/2" do
    test "appends interval suffix to column name" do
      assert TradingView.column_with_interval("RSI", "1h") == "RSI|60"
      assert TradingView.column_with_interval("RSI", "1d") == "RSI"
      assert TradingView.column_with_interval("MACD.macd", "4h") == "MACD.macd|240"
      assert TradingView.column_with_interval("Recommend.All", "1W") == "Recommend.All|1W"
    end
  end

  describe "format_ticker/2" do
    test "formats ticker correctly" do
      assert TradingView.format_ticker("TSLA", "NASDAQ") == "NASDAQ:TSLA"
      assert TradingView.format_ticker("btcusd", "binance") == "BINANCE:BTCUSD"
    end
  end

  describe "classify_recommendation/1" do
    test "classifies strong buy" do
      assert TradingView.classify_recommendation(0.7) == "STRONG_BUY"
      assert TradingView.classify_recommendation(0.5) == "STRONG_BUY"
    end

    test "classifies buy" do
      assert TradingView.classify_recommendation(0.3) == "BUY"
      assert TradingView.classify_recommendation(0.1) == "BUY"
    end

    test "classifies neutral" do
      assert TradingView.classify_recommendation(0.0) == "NEUTRAL"
      assert TradingView.classify_recommendation(0.05) == "NEUTRAL"
      assert TradingView.classify_recommendation(-0.05) == "NEUTRAL"
    end

    test "classifies sell" do
      assert TradingView.classify_recommendation(-0.3) == "SELL"
      assert TradingView.classify_recommendation(-0.1) == "SELL"
    end

    test "classifies strong sell" do
      assert TradingView.classify_recommendation(-0.7) == "STRONG_SELL"
      assert TradingView.classify_recommendation(-0.5) == "STRONG_SELL"
    end

    test "handles nil" do
      assert TradingView.classify_recommendation(nil) == "NEUTRAL"
    end
  end

  describe "column lists" do
    test "recommendation_columns returns non-empty list" do
      columns = TradingView.recommendation_columns()
      assert is_list(columns)
      assert length(columns) > 0
      assert "Recommend.All" in columns
    end

    test "oscillator_columns returns non-empty list" do
      columns = TradingView.oscillator_columns()
      assert is_list(columns)
      assert "RSI" in columns
      assert "MACD.macd" in columns
    end

    test "moving_average_columns returns non-empty list" do
      columns = TradingView.moving_average_columns()
      assert is_list(columns)
      assert "EMA50" in columns
      assert "SMA200" in columns
    end

    test "price_columns returns non-empty list" do
      columns = TradingView.price_columns()
      assert is_list(columns)
      assert "close" in columns
      assert "volume" in columns
    end

    test "pivot_columns returns non-empty list" do
      columns = TradingView.pivot_columns()
      assert is_list(columns)
      assert "Pivot.M.Classic.Middle" in columns
    end

    test "all_columns includes all column categories" do
      all = TradingView.all_columns()
      assert "Recommend.All" in all
      assert "RSI" in all
      assert "EMA50" in all
      assert "close" in all
      assert "Pivot.M.Classic.Middle" in all
    end
  end

  describe "intervals/0" do
    test "returns all supported intervals" do
      intervals = TradingView.intervals()
      assert "1m" in intervals
      assert "1d" in intervals
      assert "1W" in intervals
    end
  end

  describe "screeners/0" do
    test "returns all supported screeners" do
      screeners = TradingView.screeners()
      assert "america" in screeners
      assert "crypto" in screeners
      assert "forex" in screeners
    end
  end

  describe "headers/0" do
    test "returns content-type header" do
      headers = TradingView.headers()
      assert {"content-type", "application/json"} in headers
    end
  end
end
