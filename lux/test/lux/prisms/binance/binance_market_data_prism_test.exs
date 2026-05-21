defmodule Lux.Prisms.Binance.BinanceMarketDataPrismTest do
  use ExUnit.Case

  alias Lux.Prisms.Binance.BinanceMarketDataPrism

  describe "handler/2" do
    @tag :integration
    test "fetches order book for SPOT market" do
      input = %{
        "symbol" => "BTCUSDT",
        "data_type" => "ORDER_BOOK",
        "market_type" => "SPOT",
        "limit" => 5
      }

      assert {:ok, result} = BinanceMarketDataPrism.handler(input, nil)
      assert result.status == "success"
      assert is_map(result.data)
      assert Map.has_key?(result.data, "order_book")
    end

    @tag :integration
    test "fetches klines for FUTURES market" do
      input = %{
        "symbol" => "ETHUSDT",
        "data_type" => "KLINES",
        "market_type" => "FUTURES",
        "interval" => "15m",
        "limit" => 2
      }

      assert {:ok, result} = BinanceMarketDataPrism.handler(input, nil)
      assert result.status == "success"
      assert Map.has_key?(result.data, "klines")
      assert length(result.data["klines"]) == 2
    end
  end
end
