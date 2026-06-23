defmodule Lux.Prisms.Curve.CurvePoolPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.CurvePoolPrism

  test "has correct schema" do
    assert CurvePoolPrism.view().name == "Curve Finance Pool Operations"
  end
end
