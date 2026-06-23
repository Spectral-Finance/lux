defmodule Lux.Prisms.Curve.CurveGaugePrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.CurveGaugePrism

  test "has correct schema" do
    assert CurveGaugePrism.view().name == "Curve Finance Gauge Operations"
  end
end
