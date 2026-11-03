defmodule Lux.Prisms.BinancePrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Binance.SpotOrderPrism
  alias Lux.Prisms.Binance.FuturesOrderPrism
  alias Lux.Prisms.Binance.AccountBalancePrism
  alias Lux.Prisms.Binance.MarketDepthPrism
  alias Lux.Prisms.Binance.PositionRiskPrism

  describe "SpotOrderPrism" do
    test "validates spot order" do
      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 0.25,
        price: 64500.0
      }

      assert {:ok, result} = SpotOrderPrism.run(input)
      assert result.status == "validated"
      assert result.quantity == 0.25
    end
  end

  describe "FuturesOrderPrism" do
    test "validates futures order" do
      input = %{
        symbol: "ETHUSDT",
        side: "SELL",
        type: "LIMIT",
        quantity: 2.0,
        price: 2600.0,
        position_side: "BOTH"
      }

      assert {:ok, result} = FuturesOrderPrism.run(input)
      assert result.status == "validated"
      assert result.symbol == "ETHUSDT"
    end
  end

  describe "AccountBalancePrism" do
    test "calculates portfolio equity" do
      input = %{
        balances: [
          %{"asset" => "USDT", "free" => "5000.0", "locked" => "0.0"}
        ],
        prices: %{}
      }

      assert {:ok, result} = AccountBalancePrism.run(input)
      assert result.total_spot_usdt == 5000.0
    end
  end

  describe "MarketDepthPrism" do
    test "calculates top bid/ask and spread" do
      input = %{
        symbol: "BTCUSDT",
        bids: [[60000.0, 1.0]],
        asks: [[60010.0, 1.2]]
      }

      assert {:ok, result} = MarketDepthPrism.run(input)
      assert result.best_bid == 60000.0
      assert result.best_ask == 60010.0
      assert result.spread_usd == 10.0
    end
  end

  describe "PositionRiskPrism" do
    test "calculates liquidation price and pnl" do
      input = %{
        side: "BUY",
        entry_price: 60000.0,
        mark_price: 63000.0,
        quantity: 1.0,
        leverage: 10
      }

      assert {:ok, result} = PositionRiskPrism.run(input)
      assert result.unrealized_pnl == 3000.0
      assert result.roe_pct == 50.0
      assert result.liquidation_price < 60000.0
    end
  end
end
