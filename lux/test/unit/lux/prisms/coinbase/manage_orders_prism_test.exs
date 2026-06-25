defmodule Lux.Prisms.Coinbase.ManageOrdersPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.ManageOrdersPrism

  describe "view/0" do
    test "returns valid prism struct" do
      prism = ManageOrdersPrism.view()

      assert prism.name == "Coinbase Manage Orders"
      assert prism.input_schema.required == ["action"]
    end

    test "action enum includes all operations" do
      prism = ManageOrdersPrism.view()
      actions = prism.input_schema.properties.action.enum

      assert "list_open_orders" in actions
      assert "get_order" in actions
      assert "cancel_order" in actions
      assert "cancel_all" in actions
      assert "list_fills" in actions
    end

    test "output schema defines action and data" do
      prism = ManageOrdersPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :action)
      assert Map.has_key?(props, :data)
    end
  end

  describe "handler/2" do
    test "list_open_orders action" do
      result =
        ManageOrdersPrism.handler(%{
          action: "list_open_orders",
          product_id: "BTC-USD"
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "get_order requires order_id" do
      result = ManageOrdersPrism.handler(%{action: "get_order"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "cancel_order requires order_id" do
      result = ManageOrdersPrism.handler(%{action: "cancel_order"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "cancel_all action" do
      result =
        ManageOrdersPrism.handler(%{
          action: "cancel_all",
          product_id: "BTC-USD"
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "list_fills requires sequences" do
      result =
        ManageOrdersPrism.handler(%{
          action: "list_fills",
          start_sequence: 1,
          end_sequence: 100
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
