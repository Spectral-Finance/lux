defmodule Lux.Prisms.Curve.CurvePoolAnalysisPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.CurvePoolAnalysisPrism

  test "has correct schema" do
    assert CurvePoolAnalysisPrism.view().name == "Curve Finance Pool Analysis"
  end
end
