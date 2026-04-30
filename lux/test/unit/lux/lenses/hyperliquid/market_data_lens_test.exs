defmodule Lux.Lenses.Hyperliquid.MarketDataLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.MarketDataLens

  describe "process_market_data/1" do
    test "processes market data correctly" do
      meta = %{
        "universe" => [
          %{"name" => "BTC", "szDecimals" => 5},
          %{"name" => "ETH", "szDecimals" => 6}
        ]
      }

      asset_ctxs = [
        %{
          "markPx" => "104050.0",
          "midPx" => "104045.0",
          "funding" => "0.0000125",
          "openInterest" => "50000.0",
          "dayNtlVlm" => "125000000.0",
          "prevDayPx" => "103500.0",
          "oraclePx" => "104000.0",
          "impactPxs" => ["104040.0", "104050.0"]
        },
        %{
          "markPx" => "2800.0",
          "midPx" => "2799.5",
          "funding" => "0.000008",
          "openInterest" => "30000.0",
          "dayNtlVlm" => "50000000.0",
          "prevDayPx" => "2750.0",
          "oraclePx" => "2798.0",
          "impactPxs" => ["2799.0", "2800.0"]
        }
      ]

      result = MarketDataLens.process_market_data([meta, asset_ctxs])

      assert map_size(result.markets) == 2
      assert Map.has_key?(result.markets, "BTC")
      assert Map.has_key?(result.markets, "ETH")

      btc = result.markets["BTC"]
      assert btc.mark_price == "104050.0"
      assert btc.funding_rate == "0.0000125"
      assert btc.open_interest == "50000.0"

      eth = result.markets["ETH"]
      assert eth.mark_price == "2800.0"
      assert eth.size_decimals == 6
    end

    test "calculates market summary" do
      meta = %{
        "universe" => [
          %{"name" => "BTC", "szDecimals" => 5}
        ]
      }

      asset_ctxs = [
        %{
          "markPx" => "100000.0",
          "midPx" => "99999.0",
          "funding" => "0.00001",
          "openInterest" => "100000.0",
          "dayNtlVlm" => "50000000.0",
          "prevDayPx" => "99000.0",
          "oraclePx" => "100000.0",
          "impactPxs" => ["99998.0", "100000.0"]
        }
      ]

      result = MarketDataLens.process_market_data([meta, asset_ctxs])

      assert result.summary.total_markets == 1
      assert result.summary.total_open_interest == "100000.0"
      assert result.summary.total_day_volume == "50000000.0"
    end

    test "handles empty market data" do
      meta = %{"universe" => []}
      asset_ctxs = []

      result = MarketDataLens.process_market_data([meta, asset_ctxs])

      assert result.markets == %{}
      assert result.summary.total_markets == 0
    end

    test "handles map input gracefully" do
      result = MarketDataLens.process_market_data(%{"some" => "data"})

      assert result.markets == %{}
      assert result.summary.total_markets == 0
    end
  end
end
