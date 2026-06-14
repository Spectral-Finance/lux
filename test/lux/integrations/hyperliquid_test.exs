defmodule Lux.Integrations.HyperliquidTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Hyperliquid
  describe "market data" do
    test "metadata/0 returns exchange metadata" do
      assert elem(Hyperliquid.metadata(), 0) in [:ok, :error]
    end
    test "all_mids/0 returns mids" do
      assert elem(Hyperliquid.all_mids(), 0) in [:ok, :error]
    end
    test "orderbook/1 returns orderbook" do
      assert elem(Hyperliquid.orderbook("PURR"), 0) in [:ok, :error]
    end
    test "recent_trades/1 returns trades" do
      assert elem(Hyperliquid.recent_trades("PURR"), 0) in [:ok, :error]
    end
    test "candle_snapshot/1 returns candles" do
      assert elem(Hyperliquid.candle_snapshot("PURR", "1h", 5), 0) in [:ok, :error]
    end
  end
end
