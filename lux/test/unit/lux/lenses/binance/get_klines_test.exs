defmodule Lux.Lenses.Binance.Market.GetKlinesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Binance.Market.GetKlines

  @raw_kline [
    1_700_000_000_000, "50000.00", "51000.00", "49000.00", "50500.00",
    "1234.56", 1_700_003_599_999, "62345678.00", 9876,
    "600.00", "30000000.00", "0"
  ]

  describe "after_focus/1" do
    test "parses kline list into structured maps" do
      assert {:ok, [kline]} = GetKlines.after_focus([@raw_kline])

      assert kline.open_time == 1_700_000_000_000
      assert kline.open == "50000.00"
      assert kline.high == "51000.00"
      assert kline.low == "49000.00"
      assert kline.close == "50500.00"
      assert kline.volume == "1234.56"
      assert kline.close_time == 1_700_003_599_999
      assert kline.trades == 9876
    end

    test "parses multiple klines" do
      assert {:ok, klines} = GetKlines.after_focus([@raw_kline, @raw_kline])
      assert length(klines) == 2
    end

    test "returns error on API error" do
      assert {:error, %{code: -1121}} =
        GetKlines.after_focus(%{"code" => -1121, "msg" => "Invalid symbol."})
    end
  end

  describe "schema" do
    test "requires symbol and interval" do
      lens = GetKlines.view()
      assert "symbol" in lens.schema.required
      assert "interval" in lens.schema.required
    end
  end
end
