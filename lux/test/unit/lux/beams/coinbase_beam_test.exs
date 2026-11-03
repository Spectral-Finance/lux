defmodule Lux.Beams.CoinbaseBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Coinbase.CoinbaseTradingBeam

  describe "CoinbaseTradingBeam" do
    test "defines beam structure and schema correctly" do
      assert CoinbaseTradingBeam.name() == "Coinbase Trading Execution Beam"
      assert is_map(CoinbaseTradingBeam.input_schema())
      assert is_map(CoinbaseTradingBeam.output_schema())
    end
  end
end
