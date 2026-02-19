defmodule Lux.Lenses.Coinbase.ProductsLensTest do
  @moduledoc """
  Test suite for the Coinbase Products lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.ProductsLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses products response" do
      response = %{
        "products" => [
          %{
            "product_id" => "BTC-USD",
            "price" => "43250.00",
            "price_percentage_change_24h" => "2.5",
            "volume_24h" => "15000000.00",
            "volume_percentage_change_24h" => "10.0",
            "base_currency_id" => "BTC",
            "quote_currency_id" => "USD",
            "base_min_size" => "0.00001",
            "base_max_size" => "10000",
            "quote_min_size" => "1",
            "quote_max_size" => "1000000",
            "base_increment" => "0.00000001",
            "quote_increment" => "0.01",
            "product_type" => "SPOT",
            "status" => "online",
            "trading_disabled" => false
          },
          %{
            "product_id" => "ETH-USD",
            "price" => "2250.00",
            "price_percentage_change_24h" => "1.2",
            "volume_24h" => "8000000.00",
            "volume_percentage_change_24h" => "5.0",
            "base_currency_id" => "ETH",
            "quote_currency_id" => "USD",
            "base_min_size" => "0.0001",
            "base_max_size" => "50000",
            "quote_min_size" => "1",
            "quote_max_size" => "1000000",
            "base_increment" => "0.0000001",
            "quote_increment" => "0.01",
            "product_type" => "SPOT",
            "status" => "online",
            "trading_disabled" => false
          }
        ]
      }

      assert {:ok, %{products: products}} = ProductsLens.after_focus(response)
      assert length(products) == 2

      btc = Enum.find(products, &(&1.product_id == "BTC-USD"))
      assert btc.price == "43250.00"
      assert btc.base_currency_id == "BTC"
      assert btc.quote_currency_id == "USD"
      assert btc.product_type == "SPOT"
      assert btc.status == "online"
      assert btc.trading_disabled == false

      eth = Enum.find(products, &(&1.product_id == "ETH-USD"))
      assert eth.price == "2250.00"
      assert eth.base_currency_id == "ETH"
    end

    test "handles error response" do
      assert {:error, "Invalid request"} =
               ProductsLens.after_focus(%{"error" => "Invalid request"})
    end

    test "handles empty products list" do
      assert {:ok, %{products: []}} = ProductsLens.after_focus(%{"products" => []})
    end
  end
end
