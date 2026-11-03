defmodule Lux.Beams.TradingViewBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.TradingView.TechnicalAnalysisBeam

  describe "TechnicalAnalysisBeam" do
    test "defines beam structure and schema correctly" do
      assert TechnicalAnalysisBeam.name() == "TradingView Technical Analysis Beam"
      assert is_map(TechnicalAnalysisBeam.input_schema())
      assert is_map(TechnicalAnalysisBeam.output_schema())
    end
  end
end
