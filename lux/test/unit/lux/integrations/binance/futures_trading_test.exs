defmodule Lux.Integrations.Binance.FuturesTradingTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.FuturesTrading

  describe "build_futures_order/1" do
    test "validates perpetual futures order" do
      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 0.1,
        price: 64000.0,
        position_side: "BOTH",
        reduce_only: false
      }

      assert {:ok, params} = FuturesTrading.build_futures_order(input)
      assert params.symbol == "BTCUSDT"
      assert params.positionSide == "BOTH"
      assert params.reduceOnly == false
    end
  end

  describe "calculate_liquidation_price/4" do
    test "estimates long liquidation price with 10x leverage" do
      # Entry: 50,000, 10x leverage (10% initial margin), 0.5% MMR
      # liq = 50,000 * (1 - 0.10 + 0.005) = 50,000 * 0.905 = 45,250
      liq = FuturesTrading.calculate_liquidation_price("BUY", 50000.0, 10, 0.005)
      assert liq == 45250.0
    end

    test "estimates short liquidation price with 10x leverage" do
      # Entry: 50,000, 10x leverage, 0.5% MMR
      # liq = 50,000 * (1 + 0.10 - 0.005) = 50,000 * 1.095 = 54,750
      liq = FuturesTrading.calculate_liquidation_price("SELL", 50000.0, 10, 0.005)
      assert liq == 54750.0
    end
  end

  describe "calculate_pnl/5" do
    test "computes unrealized pnl and roe% for long position" do
      # Long 1.0 BTC @ 50,000, mark @ 52,000, 10x leverage (margin = 5,000)
      # upnl = +2,000. ROE = 2000 / 5000 * 100 = 40%
      pnl = FuturesTrading.calculate_pnl("BUY", 50000.0, 52000.0, 1.0, 10)
      assert pnl.unrealized_pnl == 2000.0
      assert pnl.roe_pct == 40.0
    end

    test "computes unrealized pnl and roe% for short position" do
      # Short 1.0 BTC @ 50,000, mark @ 48,000, 10x leverage (margin = 5,000)
      # upnl = +2,000. ROE = +40%
      pnl = FuturesTrading.calculate_pnl("SELL", 50000.0, 48000.0, 1.0, 10)
      assert pnl.unrealized_pnl == 2000.0
      assert pnl.roe_pct == 40.0
    end
  end
end
