defmodule Lux.Beams.Analytics.DefiBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Analytics.Defi.DefiAnalyticsBeam

  describe "DefiAnalyticsBeam" do
    test "defines beam structure and schema correctly" do
      assert DefiAnalyticsBeam.name() == "DeFi Protocol Analytics Beam"
      assert is_map(DefiAnalyticsBeam.input_schema())
      assert is_map(DefiAnalyticsBeam.output_schema())
    end
  end
end
