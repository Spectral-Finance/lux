defmodule Lux.Integrations.Coinbase.MarketDataTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.MarketData

  describe "map_granularity/1" do
    test "maps common interval strings" do
      assert MarketData.map_granularity("1m") == "ONE_MINUTE"
      assert MarketData.map_granularity("5m") == "FIVE_MINUTE"
      assert MarketData.map_granularity("1h") == "ONE_HOUR"
      assert MarketData.map_granularity("1d") == "ONE_DAY"
      assert MarketData.map_granularity("unknown") == "ONE_HOUR"
    end
  end

  describe "parse_candles/1" do
    test "converts candle lists into typed records" do
      raw = [
        %{"start" => "1700000000", "low" => "64000.0", "high" => "65000.0", "open" => "64200.0", "close" => "64800.0", "volume" => "12.5"}
      ]

      [c] = MarketData.parse_candles(raw)
      assert c.start == 1700000000
      assert c.low == 64000.0
      assert c.high == 65000.0
      assert c.open == 64200.0
      assert c.close == 64800.0
      assert c.volume == 12.5
    end
  end

  describe "evaluate_orderbook/2" do
    test "computes best bid, best ask, mid-market, and spread" do
      bids = [%{"price_level" => "64990.0", "new_quantity" => "1.5"}]
      asks = [%{"price_level" => "65010.0", "new_quantity" => "2.0"}]

      result = MarketData.evaluate_orderbook(bids, asks)

      assert result.best_bid == 64990.0
      assert result.best_ask == 65010.0
      assert result.mid_market == 65000.0
      assert result.spread_usd == 20.0
      assert result.spread_bps > 0.0
    end
  end
end
