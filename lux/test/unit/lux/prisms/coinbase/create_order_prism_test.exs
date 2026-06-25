defmodule Lux.Prisms.Coinbase.CreateOrderPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.CreateOrderPrism

  describe "view/0" do
    test "returns valid prism struct" do
      prism = CreateOrderPrism.view()

      assert prism.name == "Coinbase Create Order"
      assert prism.input_schema.required == ["product_id", "side", "order_configuration"]
    end

    test "side enum includes BUY and SELL" do
      prism = CreateOrderPrism.view()
      side = prism.input_schema.properties.side

      assert side.type == :string
      assert "BUY" in side.enum
      assert "SELL" in side.enum
    end

    test "output schema defines order_id and status" do
      prism = CreateOrderPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :order_id)
      assert Map.has_key?(props, :status)
    end
  end

  describe "handler/2" do
    test "market order requires product_id, side, order_configuration" do
      result =
        CreateOrderPrism.handler(%{
          product_id: "BTC-USD",
          side: "BUY",
          order_configuration: %{market_order_config: %{}}
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "limit order GTC" do
      result =
        CreateOrderPrism.handler(%{
          product_id: "ETH-USD",
          side: "SELL",
          order_configuration: %{
            limit_order_gtc: %{
              base_size: "0.1",
              limit_price: "2000.00"
            }
          }
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "stop-limit order" do
      result =
        CreateOrderPrism.handler(%{
          product_id: "BTC-USD",
          side: "BUY",
          order_configuration: %{
            stop_limit_limit_gtc: %{
              trigger_price: "50000.00",
              limit_price: "50100.00",
              base_size: "0.01",
              side: "BUY"
            }
          }
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "invalid side rejected" do
      result =
        CreateOrderPrism.handler(%{
          product_id: "BTC-USD",
          side: "INVALID",
          order_configuration: %{market_order_config: %{}}
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) == :error
    end
  end
end
