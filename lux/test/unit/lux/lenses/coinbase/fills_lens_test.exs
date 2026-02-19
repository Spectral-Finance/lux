defmodule Lux.Lenses.Coinbase.FillsLensTest do
  @moduledoc """
  Test suite for the Coinbase Fills lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.FillsLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses fills response" do
      response = %{
        "fills" => [
          %{
            "entry_id" => "entry-001",
            "trade_id" => "trade-001",
            "order_id" => "order-001",
            "trade_time" => "2024-01-01T00:00:00Z",
            "trade_type" => "FILL",
            "price" => "43250.00",
            "size" => "0.001",
            "commission" => "0.26",
            "product_id" => "BTC-USD",
            "side" => "BUY",
            "sequence_timestamp" => "2024-01-01T00:00:00Z",
            "liquidity_indicator" => "TAKER",
            "size_in_quote" => "43.25"
          }
        ],
        "cursor" => "fill-cursor"
      }

      assert {:ok, result} = FillsLens.after_focus(response)
      assert length(result.fills) == 1
      assert result.cursor == "fill-cursor"

      fill = List.first(result.fills)
      assert fill.entry_id == "entry-001"
      assert fill.trade_id == "trade-001"
      assert fill.order_id == "order-001"
      assert fill.product_id == "BTC-USD"
      assert fill.price == "43250.00"
      assert fill.size == "0.001"
      assert fill.commission == "0.26"
      assert fill.side == "BUY"
      assert fill.liquidity_indicator == "TAKER"
    end

    test "handles empty fills list" do
      assert {:ok, %{fills: []}} = FillsLens.after_focus(%{"fills" => []})
    end

    test "handles error response" do
      assert {:error, "Unauthorized"} =
               FillsLens.after_focus(%{"error" => "Unauthorized"})
    end
  end
end
