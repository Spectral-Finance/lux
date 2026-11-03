defmodule Lux.Beams.Defi.SushiSwapBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Defi.SushiSwap.SushiCrossChainSwapBeam

  describe "SushiCrossChainSwapBeam" do
    test "defines beam structure and schema correctly" do
      assert SushiCrossChainSwapBeam.name() == "SushiXSwap Cross-Chain Swap Beam"
      assert is_map(SushiCrossChainSwapBeam.input_schema())
      assert is_map(SushiCrossChainSwapBeam.output_schema())
    end
  end
end
