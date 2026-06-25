defmodule Lux.Integration.Lenses.TradingView.QuoteTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.TradingView.QuoteLens

  describe "focus/2 - quote lens" do
    test "validates lens schema" do
      lens = QuoteLens.view()
      assert lens.name == "TradingView Quotes"
      assert lens.url == "https://api.tradingview.io/v2/screener/quotes"
      assert lens.method == :get
    end

    test "transforms symbols array to comma-separated string" do
      params = %{symbols: ["BINANCE:BTCUSDT", "BINANCE:ETHUSDT"]}
      result = QuoteLens.before_focus(params)
      assert result.symbols == "BINANCE:BTCUSDT,BINANCE:ETHUSDT"
    end

    test "handles after_focus with quote data" do
      mock_response = %{
        "data" => [
          %{
            "s" => "BTCUSDT",
            "v" => %{
              "price" => 42000.0,
              "chng" => 500.0,
              "changespercentage" => 1.2,
              "volume" => 15000,
              "high" => 42500.0,
              "low" => 41500.0
            }
          }
        ]
      }

      assert {:ok, result} = QuoteLens.after_focus(mock_response)
      assert result.quotes != nil
      assert length(result.quotes) == 1
      first = hd(result.quotes)
      assert first.symbol == "BTCUSDT"
      assert first.price == 42000.0
    end

    test "handles after_focus with single quote" do
      mock_response = %{
        "data" => %{
          "s" => "ETHUSDT",
          "v" => %{"price" => 2200.0}
        }
      }

      assert {:ok, result} = QuoteLens.after_focus(mock_response)
      assert result.quote != nil
    end

    test "handles error response" do
      mock_response = %{"error" => "Invalid symbol"}
      assert {:error, "Invalid symbol"} = QuoteLens.after_focus(mock_response)
    end
  end
end
