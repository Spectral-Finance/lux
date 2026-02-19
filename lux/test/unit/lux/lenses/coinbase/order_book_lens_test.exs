defmodule Lux.Lenses.Coinbase.OrderBookLensTest do
  @moduledoc """
  Test suite for the Coinbase Order Book lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.OrderBookLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses order book response" do
      response = %{
        "pricebook" => %{
          "product_id" => "BTC-USD",
          "bids" => [
            %{"price" => "43249.00", "size" => "1.5"},
            %{"price" => "43248.00", "size" => "2.0"},
            %{"price" => "43247.00", "size" => "0.8"}
          ],
          "asks" => [
            %{"price" => "43251.00", "size" => "0.3"},
            %{"price" => "43252.00", "size" => "1.2"},
            %{"price" => "43253.00", "size" => "0.5"}
          ],
          "time" => "2024-01-01T00:00:00Z"
        }
      }

      assert {:ok, result} = OrderBookLens.after_focus(response)
      assert result.product_id == "BTC-USD"
      assert length(result.bids) == 3
      assert length(result.asks) == 3
      assert result.time == "2024-01-01T00:00:00Z"

      first_bid = List.first(result.bids)
      assert first_bid.price == "43249.00"
      assert first_bid.size == "1.5"

      first_ask = List.first(result.asks)
      assert first_ask.price == "43251.00"
      assert first_ask.size == "0.3"
    end

    test "handles empty order book" do
      response = %{
        "pricebook" => %{
          "product_id" => "BTC-USD",
          "bids" => [],
          "asks" => [],
          "time" => "2024-01-01T00:00:00Z"
        }
      }

      assert {:ok, result} = OrderBookLens.after_focus(response)
      assert result.bids == []
      assert result.asks == []
    end

    test "handles missing bids/asks gracefully" do
      response = %{
        "pricebook" => %{
          "product_id" => "BTC-USD",
          "time" => "2024-01-01T00:00:00Z"
        }
      }

      assert {:ok, result} = OrderBookLens.after_focus(response)
      assert result.bids == []
      assert result.asks == []
    end

    test "handles error response" do
      assert {:error, "Product not found"} =
               OrderBookLens.after_focus(%{"error" => "Product not found"})
    end
  end
end
