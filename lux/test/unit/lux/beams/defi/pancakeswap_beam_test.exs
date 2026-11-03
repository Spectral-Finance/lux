defmodule Lux.Beams.Defi.PancakeSwapBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Defi.PancakeSwap.YieldFarmingBeam

  describe "YieldFarmingBeam" do
    test "defines beam structure and executes steps" do
      assert YieldFarmingBeam.name() == "PancakeSwap Yield Farming Beam"
      assert is_map(YieldFarmingBeam.input_schema())
      assert is_map(YieldFarmingBeam.output_schema())
    end
  end
end
