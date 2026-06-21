defmodule Lux.Lenses.Binance.GetOrderBookTest do
  use ExUnit.Case, async: true
  
  alias Lux.Lenses.Binance.GetOrderBook

  describe "GetOrderBook Lens" do
    test "before_focus formats spot URL correctly" do
      params = %{symbol: "BTCUSDT", limit: 5}
      lens = struct(GetOrderBook)
      
      {:ok, updated_lens} = GetOrderBook.before_focus(params, lens)
      
      assert updated_lens.url == "https://api.binance.com/api/v3/depth"
      assert updated_lens.params.symbol == "BTCUSDT"
      assert updated_lens.params.limit == 5
    end

    test "before_focus formats futures URL correctly" do
      params = %{symbol: "ETHUSDT", network: "futures", limit: 10}
      lens = struct(GetOrderBook)
      
      {:ok, updated_lens} = GetOrderBook.before_focus(params, lens)
      
      assert updated_lens.url == "https://fapi.binance.com/fapi/v1/depth"
      assert updated_lens.params.symbol == "ETHUSDT"
      assert updated_lens.params.limit == 10
    end

    test "after_focus handles successful response" do
      response = %{
        "lastUpdateId" => 123456789,
        "bids" => [
          ["65000.00", "1.500"]
        ],
        "asks" => [
          ["65001.00", "0.500"]
        ]
      }
      
      assert {:ok, result} = GetOrderBook.after_focus(response)
      assert length(result.bids) == 1
      assert length(result.asks) == 1
      assert hd(result.bids).price == "65000.00"
      assert hd(result.asks).quantity == "0.500"
    end
  end
end
