defmodule Lux.Lenses.Coinbase.CandlesLensTest do
  @moduledoc """
  Test suite for the Coinbase Candles lens.
  """

  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.CandlesLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "successfully parses candles response" do
      response = %{
        "candles" => [
          %{
            "start" => "1672531200",
            "low" => "16500.00",
            "high" => "16700.00",
            "open" => "16550.00",
            "close" => "16680.00",
            "volume" => "123.45"
          },
          %{
            "start" => "1672534800",
            "low" => "16650.00",
            "high" => "16800.00",
            "open" => "16680.00",
            "close" => "16750.00",
            "volume" => "98.76"
          }
        ]
      }

      assert {:ok, %{candles: candles}} = CandlesLens.after_focus(response)
      assert length(candles) == 2

      first = List.first(candles)
      assert first.start == "1672531200"
      assert first.low == "16500.00"
      assert first.high == "16700.00"
      assert first.open == "16550.00"
      assert first.close == "16680.00"
      assert first.volume == "123.45"
    end

    test "handles empty candles list" do
      assert {:ok, %{candles: []}} = CandlesLens.after_focus(%{"candles" => []})
    end

    test "handles error response" do
      assert {:error, "Invalid product_id"} =
               CandlesLens.after_focus(%{"error" => "Invalid product_id"})
    end
  end

  describe "before_focus/1" do
    test "generates URL override with product_id" do
      params = %{product_id: "BTC-USD", start: "1672531200", end: "1672617600", granularity: "ONE_HOUR"}
      result = CandlesLens.before_focus(params)

      assert result.__url_override__ ==
               "https://api.coinbase.com/api/v3/brokerage/products/BTC-USD/candles"

      refute Map.has_key?(result, :product_id)
      assert result.start == "1672531200"
      assert result.granularity == "ONE_HOUR"
    end
  end
end
