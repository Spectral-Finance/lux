defmodule Lux.Integrations.Binance.SpotTradingTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.SpotTrading

  describe "build_order_params/1" do
    test "validates limit order successfully" do
      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 0.05,
        price: 65000.0,
        time_in_force: "GTC"
      }

      assert {:ok, params} = SpotTrading.build_order_params(input)
      assert params.symbol == "BTCUSDT"
      assert params.side == "BUY"
      assert params.type == "LIMIT"
      assert params.quantity == 0.05
      assert params.price == 65000.0
      assert params.timeInForce == "GTC"
    end

    test "validates market order without price" do
      input = %{
        symbol: "ETHUSDT",
        side: "SELL",
        type: "MARKET",
        quantity: 1.5
      }

      assert {:ok, params} = SpotTrading.build_order_params(input)
      assert params.type == "MARKET"
      assert is_nil(Map.get(params, :price))
      assert is_nil(Map.get(params, :timeInForce))
    end

    test "fails with missing symbol" do
      assert {:error, "Symbol is required"} = SpotTrading.build_order_params(%{side: "BUY", quantity: 1.0})
    end

    test "fails with invalid side" do
      assert {:error, "Invalid side: HOLD. Must be BUY or SELL"} =
               SpotTrading.build_order_params(%{symbol: "BTCUSDT", side: "HOLD", quantity: 1.0})
    end

    test "fails limit order without price" do
      assert {:error, "Price is required for LIMIT orders"} =
               SpotTrading.build_order_params(%{symbol: "BTCUSDT", side: "BUY", type: "LIMIT", quantity: 1.0})
    end
  end

  describe "build_cancel_params/3" do
    test "builds cancel params with order_id" do
      assert {:ok, params} = SpotTrading.build_cancel_params("BTCUSDT", 12345678)
      assert params.symbol == "BTCUSDT"
      assert params.orderId == 12345678
    end

    test "fails without order_id or orig_client_order_id" do
      assert {:error, "Either order_id or orig_client_order_id must be provided"} =
               SpotTrading.build_cancel_params("BTCUSDT")
    end
  end
end
