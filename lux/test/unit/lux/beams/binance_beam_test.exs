defmodule Lux.Beams.BinanceBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Binance.BinanceTradingBeam

  describe "BinanceTradingBeam" do
    test "defines beam structure and schema correctly" do
      assert BinanceTradingBeam.name() == "Binance Trading Execution Beam"
      assert is_map(BinanceTradingBeam.input_schema())
      assert is_map(BinanceTradingBeam.output_schema())
    end
  end
end
