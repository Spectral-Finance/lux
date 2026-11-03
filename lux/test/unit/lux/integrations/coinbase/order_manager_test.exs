defmodule Lux.Integrations.Coinbase.OrderManagerTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.OrderManager

  describe "generate_client_order_id/0" do
    test "generates valid UUIDv4 format" do
      uuid = OrderManager.generate_client_order_id()
      assert String.length(uuid) == 36
      assert uuid =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
    end
  end

  describe "build_order/1" do
    test "builds limit order payload" do
      input = %{
        product_id: "BTC-USD",
        side: "BUY",
        type: "LIMIT",
        base_size: 0.1,
        limit_price: 65000.0
      }

      assert {:ok, payload} = OrderManager.build_order(input)
      assert payload["product_id"] == "BTC-USD"
      assert payload["side"] == "BUY"
      assert is_binary(payload["client_order_id"])

      limit_cfg = payload["order_configuration"]["limit_limit_gtc"]
      assert limit_cfg["base_size"] == "0.1"
      assert limit_cfg["limit_price"] == "65000.0"
    end

    test "builds market order payload" do
      input = %{
        product_id: "ETH-USD",
        side: "SELL",
        type: "MARKET",
        base_size: 2.5
      }

      assert {:ok, payload} = OrderManager.build_order(input)
      assert payload["product_id"] == "ETH-USD"
      assert payload["side"] == "SELL"

      market_cfg = payload["order_configuration"]["market_market_ioc"]
      assert market_cfg["base_size"] == "2.5"
    end

    test "fails with missing product_id" do
      assert {:error, "product_id is required (e.g. BTC-USD)"} =
               OrderManager.build_order(%{side: "BUY", base_size: 1.0})
    end

    test "fails with invalid side" do
      assert {:error, "Invalid side: HOLD. Must be BUY or SELL"} =
               OrderManager.build_order(%{product_id: "BTC-USD", side: "HOLD", base_size: 1.0})
    end
  end

  describe "build_cancel_order/1" do
    test "formats batch cancellation payload" do
      ids = ["order-1", "order-2"]
      assert {:ok, payload} = OrderManager.build_cancel_order(ids)
      assert payload["order_ids"] == ids
    end

    test "fails on empty list" do
      assert {:error, _} = OrderManager.build_cancel_order([])
    end
  end
end
