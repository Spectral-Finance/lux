defmodule Lux.Lenses.Coinbase.OrdersLensTest do
  @moduledoc """
  Test suite for the Coinbase Orders lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.OrdersLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses orders response" do
      response = %{
        "orders" => [
          %{
            "order_id" => "order-001",
            "product_id" => "BTC-USD",
            "side" => "BUY",
            "status" => "FILLED",
            "order_type" => "LIMIT",
            "created_time" => "2024-01-01T00:00:00Z",
            "completion_percentage" => "100",
            "filled_size" => "0.001",
            "average_filled_price" => "43250.00",
            "total_fees" => "0.26",
            "total_value_after_fees" => "43.51",
            "order_configuration" => %{
              "limit_limit_gtc" => %{
                "base_size" => "0.001",
                "limit_price" => "43250.00"
              }
            },
            "settled" => true
          },
          %{
            "order_id" => "order-002",
            "product_id" => "ETH-USD",
            "side" => "SELL",
            "status" => "OPEN",
            "order_type" => "LIMIT",
            "created_time" => "2024-01-02T00:00:00Z",
            "completion_percentage" => "0",
            "filled_size" => "0",
            "average_filled_price" => "0",
            "total_fees" => "0",
            "total_value_after_fees" => "0",
            "order_configuration" => %{
              "limit_limit_gtc" => %{
                "base_size" => "1.0",
                "limit_price" => "2500.00"
              }
            },
            "settled" => false
          }
        ],
        "cursor" => "next-cursor",
        "has_next" => true
      }

      assert {:ok, result} = OrdersLens.after_focus(response)
      assert length(result.orders) == 2
      assert result.cursor == "next-cursor"
      assert result.has_next == true

      filled_order = Enum.find(result.orders, &(&1.order_id == "order-001"))
      assert filled_order.product_id == "BTC-USD"
      assert filled_order.side == "BUY"
      assert filled_order.status == "FILLED"
      assert filled_order.filled_size == "0.001"
      assert filled_order.average_filled_price == "43250.00"
      assert filled_order.settled == true

      open_order = Enum.find(result.orders, &(&1.order_id == "order-002"))
      assert open_order.status == "OPEN"
      assert open_order.settled == false
    end

    test "handles empty orders list" do
      assert {:ok, %{orders: []}} = OrdersLens.after_focus(%{"orders" => []})
    end

    test "handles error response" do
      assert {:error, "Unauthorized"} =
               OrdersLens.after_focus(%{"error" => "Unauthorized"})
    end
  end
end
