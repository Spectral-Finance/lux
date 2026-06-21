defmodule Lux.Prisms.Coinbase.PlaceOrderTest do
  use ExUnit.Case, async: false

  import Mock
  alias Lux.Prisms.Coinbase.PlaceOrder
  alias Lux.Integrations.Coinbase.Client

  @moduletag :unit

  describe "handler/2" do
    test "successfully places a limit order" do
      params = %{
        product_id: "BTC-USD",
        side: "BUY",
        type: "LIMIT",
        quantity: "1.5",
        price: "65000.0"
      }

      with_mock Client,
        request: fn :post, "/api/v3/brokerage/orders", opts ->
          assert opts[:signed] == true
          assert opts[:json]["product_id"] == "BTC-USD"
          assert opts[:json]["side"] == "BUY"
          assert opts[:json]["order_configuration"]["limit_limit_gtc"]["limit_price"] == "65000.0"

          {:ok, %{"success" => true, "order_id" => "111-222"}}
        end do
        assert {:ok, result} = PlaceOrder.handler(params, %{})
        assert result["success"] == true
        assert result["order_id"] == "111-222"
      end
    end
  end
end
