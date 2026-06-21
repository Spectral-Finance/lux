defmodule Lux.Prisms.Binance.PlaceOrderTest do
  use ExUnit.Case, async: false
  
  import Mock
  alias Lux.Prisms.Binance.PlaceOrder
  alias Lux.Integrations.Binance.Client

  @moduletag :unit

  describe "handler/2" do
    test "successfully places an order on spot" do
      params = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: "1.5",
        price: "65000.0",
        network: "spot"
      }
      
      with_mock Client, [request: fn(:post, "/api/v3/order", opts) ->
        assert opts[:network] == :spot
        assert opts[:signed] == true
        assert opts[:params].symbol == "BTCUSDT"
        assert opts[:params].type == "LIMIT"
        assert opts[:params].price == "65000.0"
        
        {:ok, %{"orderId" => 12345, "status" => "NEW", "symbol" => "BTCUSDT"}}
      end] do
        assert {:ok, result} = PlaceOrder.handler(params, %{})
        assert result["orderId"] == 12345
        assert result["status"] == "NEW"
        assert result["symbol"] == "BTCUSDT"
      end
    end

    test "handles api error" do
      params = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "MARKET",
        quantity: "1.5"
      }
      
      with_mock Client, [request: fn(:post, "/api/v3/order", _opts) ->
        {:error, {400, -1013, "Filter failure: MIN_NOTIONAL"}}
      end] do
        assert {:error, error_msg} = PlaceOrder.handler(params, %{})
        assert error_msg =~ "MIN_NOTIONAL"
      end
    end
  end
end
