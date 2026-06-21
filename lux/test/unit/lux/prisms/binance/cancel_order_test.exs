defmodule Lux.Prisms.Binance.CancelOrderTest do
  use ExUnit.Case, async: false
  
  import Mock
  alias Lux.Prisms.Binance.CancelOrder
  alias Lux.Integrations.Binance.Client

  @moduletag :unit

  describe "handler/2" do
    test "successfully cancels an order on futures" do
      params = %{
        symbol: "BTCUSDT",
        order_id: "12345",
        network: "futures"
      }
      
      with_mock Client, [request: fn(:delete, "/fapi/v1/order", opts) ->
        assert opts[:network] == :futures
        assert opts[:signed] == true
        assert opts[:params].orderId == "12345"
        
        {:ok, %{"orderId" => 12345, "status" => "CANCELED", "symbol" => "BTCUSDT"}}
      end] do
        assert {:ok, result} = CancelOrder.handler(params, %{})
        assert result["orderId"] == 12345
        assert result["status"] == "CANCELED"
      end
    end
  end
end
