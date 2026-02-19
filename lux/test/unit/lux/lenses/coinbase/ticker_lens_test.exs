defmodule Lux.Lenses.Coinbase.TickerLensTest do
  @moduledoc """
  Test suite for the Coinbase Ticker (Market Trades) lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.TickerLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses market trades response" do
      response = %{
        "trades" => [
          %{
            "trade_id" => "trade-001",
            "product_id" => "BTC-USD",
            "price" => "43250.00",
            "size" => "0.001",
            "time" => "2024-01-01T00:00:00Z",
            "side" => "BUY"
          },
          %{
            "trade_id" => "trade-002",
            "product_id" => "BTC-USD",
            "price" => "43251.00",
            "size" => "0.005",
            "time" => "2024-01-01T00:00:01Z",
            "side" => "SELL"
          }
        ],
        "best_bid" => "43249.00",
        "best_ask" => "43251.00"
      }

      assert {:ok, result} = TickerLens.after_focus(response)
      assert length(result.trades) == 2
      assert result.best_bid == "43249.00"
      assert result.best_ask == "43251.00"

      first = List.first(result.trades)
      assert first.trade_id == "trade-001"
      assert first.product_id == "BTC-USD"
      assert first.price == "43250.00"
      assert first.side == "BUY"
    end

    test "handles empty trades" do
      response = %{
        "trades" => [],
        "best_bid" => "43249.00",
        "best_ask" => "43251.00"
      }

      assert {:ok, result} = TickerLens.after_focus(response)
      assert result.trades == []
    end

    test "handles error response" do
      assert {:error, "Invalid product"} =
               TickerLens.after_focus(%{"error" => "Invalid product"})
    end
  end

  describe "before_focus/1" do
    test "generates URL override with product_id" do
      params = %{product_id: "ETH-USD", limit: 10}
      result = TickerLens.before_focus(params)

      assert result.__url_override__ ==
               "https://api.coinbase.com/api/v3/brokerage/products/ETH-USD/ticker"

      refute Map.has_key?(result, :product_id)
      assert result.limit == 10
    end
  end
end
