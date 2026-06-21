defmodule Lux.Prisms.Binance.BinancePrismsTest do
  use ExUnit.Case, async: true
  
  import Mock
  alias Lux.Prisms.Binance.{PlaceOrder, CancelOrder}
  alias Lux.Integrations.Binance.Client

  describe "PlaceOrder Prism" do
    test "successfully places an order" do
      params = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 1.5,
        price: 65000.0,
        network: "spot"
      }
      
      with_mock Client, [request: fn(:post, "/api/v3/order", opts) ->
        assert opts[:network] == :spot
        assert opts[:signed] == true
        assert opts[:params][:symbol] == "BTCUSDT"
        assert opts[:params][:type] == "LIMIT"
        assert opts[:params][:price] == 65000.0
        
        {:ok, %{"orderId" => 12345, "status" => "NEW", "symbol" => "BTCUSDT"}}
      end] do
        assert {:ok, result} = PlaceOrder.handler(params, %{})
        assert result.order_id == "12345"
        assert result.status == "NEW"
        assert result.symbol == "BTCUSDT"
      end
    end

    test "handles api error when placing order" do
      params = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "MARKET",
        quantity: 1.5
      }
      
      with_mock Client, [request: fn(:post, "/api/v3/order", _opts) ->
        {:error, {400, -1013, "Filter failure: MIN_NOTIONAL"}}
      end] do
        assert {:error, error_msg} = PlaceOrder.handler(params, %{})
        assert error_msg =~ "Filter failure: MIN_NOTIONAL"
      end
    end
  end

  describe "CancelOrder Prism" do
    test "successfully cancels an order" do
      params = %{
        symbol: "BTCUSDT",
        order_id: "12345",
        network: "futures"
      }
      
      with_mock Client, [request: fn(:delete, "/fapi/v1/order", opts) ->
        assert opts[:network] == :futures
        assert opts[:signed] == true
        assert opts[:params][:orderId] == "12345"
        
        {:ok, %{"orderId" => 12345, "status" => "CANCELED", "symbol" => "BTCUSDT"}}
      end] do
        assert {:ok, result} = CancelOrder.handler(params, %{})
        assert result.order_id == "12345"
        assert result.status == "CANCELED"
      end
    end
  end
end
