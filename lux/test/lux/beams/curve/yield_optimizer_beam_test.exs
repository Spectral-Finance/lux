defmodule Lux.Beams.Curve.YieldOptimizerBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Curve.YieldOptimizerBeam

  test "has correct schema" do
    assert YieldOptimizerBeam.view().name == "Curve Yield Optimizer"
  end
end
