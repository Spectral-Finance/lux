defmodule Lux.Integration.Lenses.TradingView.ChartDataTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.TradingView.ChartDataLens

  describe "focus/2 - chart data lens" do
    test "validates lens schema" do
      lens = ChartDataLens.view()
      assert lens.name == "TradingView Chart Data"
      assert lens.url == "https://api.tradingview.io/v3/quotes/candles"
      assert lens.method == :get
      assert is_map(lens.schema)
    end

    test "transforms params correctly in before_focus" do
      params = %{symbol: "BINANCE:BTCUSDT", interval: "D", from: 1700000000, to: 1700604800}
      result = ChartDataLens.before_focus(params)
      assert result.symbol == "BINANCE:BTCUSDT"
      assert result.interval == "D"
    end

    test "handles after_focus with successful candle data" do
      mock_response = %{
        "data" => [
          %{
            "symbol" => "BTCUSDT",
            "open" => "42000.00",
            "high" => "43000.00",
            "low" => "41500.00",
            "close" => "42500.00",
            "volume" => "1500.50",
            "time" => 1700000000,
            "status" => "ok"
          }
        ]
      }

      assert {:ok, result} = ChartDataLens.after_focus(mock_response)
      assert result.candles != nil
      assert length(result.candles) == 1
      first = hd(result.candles)
      assert first.open == 42000.0
      assert first.high == 43000.0
      assert first.low == 41500.0
      assert first.close == 42500.0
      assert first.volume == 1500.5
    end

    test "handles after_focus with error response" do
      mock_response = %{"error" => "Symbol not found"}
      assert {:error, "Symbol not found"} = ChartDataLens.after_focus(mock_response)
    end

    test "handles after_focus with summary response" do
      mock_response = %{"summary" => %{"count" => 5}}
      assert {:ok, result} = ChartDataLens.after_focus(mock_response)
      assert result.summary["count"] == 5
    end
  end
end
