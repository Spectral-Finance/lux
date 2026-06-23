defmodule Lux.Prisms.Curve.CurveRewardsPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.CurveRewardsPrism

  test "has correct schema" do
    assert CurveRewardsPrism.view().name == "Curve Finance Rewards Operations"
  end
end
