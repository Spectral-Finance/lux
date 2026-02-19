defmodule Lux.Lenses.Coinbase.BestBidAskLensTest do
  @moduledoc """
  Test suite for the Coinbase Best Bid/Ask lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.BestBidAskLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses best bid/ask response" do
      response = %{
        "pricebooks" => [
          %{
            "product_id" => "BTC-USD",
            "bids" => [%{"price" => "43249.00", "size" => "1.5"}],
            "asks" => [%{"price" => "43251.00", "size" => "0.8"}],
            "time" => "2024-01-01T00:00:00Z"
          },
          %{
            "product_id" => "ETH-USD",
            "bids" => [%{"price" => "2249.00", "size" => "10.0"}],
            "asks" => [%{"price" => "2251.00", "size" => "5.0"}],
            "time" => "2024-01-01T00:00:00Z"
          }
        ]
      }

      assert {:ok, %{pricebooks: pricebooks}} = BestBidAskLens.after_focus(response)
      assert length(pricebooks) == 2

      btc = Enum.find(pricebooks, &(&1.product_id == "BTC-USD"))
      assert hd(btc.bids).price == "43249.00"
      assert hd(btc.asks).price == "43251.00"
      assert btc.time == "2024-01-01T00:00:00Z"

      eth = Enum.find(pricebooks, &(&1.product_id == "ETH-USD"))
      assert hd(eth.bids).price == "2249.00"
    end

    test "handles empty pricebooks" do
      assert {:ok, %{pricebooks: []}} = BestBidAskLens.after_focus(%{"pricebooks" => []})
    end

    test "handles error response" do
      assert {:error, "Unauthorized"} = BestBidAskLens.after_focus(%{"error" => "Unauthorized"})
    end
  end
end
