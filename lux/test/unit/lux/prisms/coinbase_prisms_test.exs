defmodule Lux.Prisms.CoinbasePrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.OrderPrism
  alias Lux.Prisms.Coinbase.AccountsPrism
  alias Lux.Prisms.Coinbase.ProductCandlesPrism
  alias Lux.Prisms.Coinbase.OrderbookPrism
  alias Lux.Prisms.Coinbase.FeeEstimatePrism

  describe "OrderPrism" do
    test "validates limit order" do
      input = %{
        product_id: "BTC-USD",
        side: "BUY",
        type: "LIMIT",
        base_size: 0.15,
        limit_price: 64800.0
      }

      assert {:ok, result} = OrderPrism.run(input)
      assert result.status == "validated"
      assert result.product_id == "BTC-USD"
      assert is_binary(result.client_order_id)
    end
  end

  describe "AccountsPrism" do
    test "aggregates accounts equity" do
      input = %{
        accounts: [
          %{"currency" => "USD", "available_balance" => %{"value" => "2500.0"}}
        ],
        prices: %{}
      }

      assert {:ok, result} = AccountsPrism.run(input)
      assert result.total_portfolio_usd == 2500.0
    end
  end

  describe "ProductCandlesPrism" do
    test "maps candles and interval" do
      input = %{
        candles: [
          %{"start" => "1700000000", "low" => "100.0", "high" => "105.0", "open" => "101.0", "close" => "104.0", "volume" => "50.0"}
        ],
        interval: "15m"
      }

      assert {:ok, result} = ProductCandlesPrism.run(input)
      assert result.granularity == "FIFTEEN_MINUTE"
      assert result.count == 1
    end
  end

  describe "OrderbookPrism" do
    test "evaluates best bid and ask" do
      input = %{
        product_id: "ETH-USD",
        bids: [%{"price_level" => "2600.0"}],
        asks: [%{"price_level" => "2601.5"}]
      }

      assert {:ok, result} = OrderbookPrism.run(input)
      assert result.best_bid == 2600.0
      assert result.best_ask == 2601.5
      assert result.spread_usd == 1.5
    end
  end

  describe "FeeEstimatePrism" do
    test "calculates estimated fee" do
      input = %{
        quantity: 2.0,
        price: 3000.0,
        fee_type: "taker"
      }

      assert {:ok, result} = FeeEstimatePrism.run(input)
      assert result.notional_usd == 6000.0
      assert result.estimated_fee_usd == 36.0
    end
  end
end
