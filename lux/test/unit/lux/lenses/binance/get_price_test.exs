defmodule Lux.Lenses.Binance.Market.GetPriceTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.Market.GetPrice

  describe "after_focus/1" do
    test "parses single symbol price response" do
      assert {:ok, %{symbol: "BTCUSDT", price: "50000.00000000"}} =
        GetPrice.after_focus(%{"symbol" => "BTCUSDT", "price" => "50000.00000000"})
    end

    test "parses all symbols price list" do
      assert {:ok, prices} = GetPrice.after_focus([
        %{"symbol" => "BTCUSDT", "price" => "50000.00"},
        %{"symbol" => "ETHUSDT", "price" => "3000.00"}
      ])

      assert length(prices) == 2
      assert Enum.find(prices, &(&1.symbol == "BTCUSDT"))
      assert Enum.find(prices, &(&1.symbol == "ETHUSDT"))
    end

    test "returns error on API error response" do
      assert {:error, %{code: -1121, message: "Invalid symbol."}} =
        GetPrice.after_focus(%{"code" => -1121, "msg" => "Invalid symbol."})
    end
  end

  describe "schema" do
    test "symbol is optional" do
      lens = GetPrice.view()
      refute "symbol" in (lens.schema[:required] || [])
    end
  end
end
