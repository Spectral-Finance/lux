defmodule Lux.Trading.Hyperliquid.OrderManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Trading.Hyperliquid.OrderManager

  describe "build_order/1" do
    test "builds valid limit order" do
      params = %{
        coin: "ETH",
        is_buy: true,
        sz: 0.5,
        limit_px: 2800.0,
        order_type: "limit",
        tif: "gtc"
      }

      assert {:ok, order} = OrderManager.build_order(params)
      assert order.coin == "ETH"
      assert order.is_buy == true
      assert order.sz == 0.5
      assert order.limit_px == 2800.0
      assert order.order_type == :limit
      assert order.tif == :gtc
      assert String.starts_with?(order.id, "hl_ord_")
    end

    test "builds valid stop loss order" do
      params = %{
        coin: "BTC",
        is_buy: false,
        sz: 0.1,
        order_type: "stop_loss",
        trigger_px: 60000.0,
        reduce_only: true
      }

      assert {:ok, order} = OrderManager.build_order(params)
      assert order.order_type == :stop_loss
      assert order.trigger_px == 60000.0
      assert order.reduce_only == true
    end

    test "rejects missing coin or invalid size" do
      assert {:error, :missing_coin} = OrderManager.build_order(%{sz: 1.0, limit_px: 2000.0})
      assert {:error, :invalid_size} = OrderManager.build_order(%{coin: "ETH", sz: 0.0, limit_px: 2000.0})
    end
  end

  describe "required_margin/2" do
    test "calculates notional divided by leverage" do
      {:ok, order} = OrderManager.build_order(%{coin: "ETH", sz: 2.0, limit_px: 3000.0})
      # Notional = 6000, Leverage = 10 -> Required = 600.0
      margin = OrderManager.required_margin(order, 10)
      assert margin == 600.0
    end
  end
end
