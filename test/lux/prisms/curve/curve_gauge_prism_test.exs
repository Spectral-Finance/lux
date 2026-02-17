defmodule Test.Lux.Prisms.Curve.CurveGaugePrismTest do
  use ExUnit.Case
  alias Lux.Prisms.Curve.CurveGaugePrism

  test "should return the correct gauge value for a given curve" do
    curve = %Curve{points: [{0, 0}, {1, 2}, {3, 4}]}
    expected_gauge_value = 2.5
    assert CurveGaugePrism.calculate_gauge(curve) == expected_gauge_value
  end

  test "should handle an empty curve" do
    curve = %Curve{points: []}
    expected_gauge_value = 0
    assert CurveGaugePrism.calculate_gauge(curve) == expected_gauge_value
  end

  test "should handle a single point curve" do
    curve = %Curve{points: [{1, 2}]}
    expected_gauge_value = 2
    assert CurveGaugePrism.calculate_gauge(curve) == expected_gauge_value
  end

  test "should handle a curve with negative points" do
    curve = %Curve{points: [{-1, -2}, {0, 0}, {1, 2}]}
    expected_gauge_value = 1.5
    assert CurveGaugePrism.calculate_gauge(curve) == expected_gauge_value
  end
end

setup do
    curve = %Curve{points: [{0, 0}, {1, 2}, {3, 4}]}
    expected_gauge_value = 2.5

    {:ok, curve: curve, expected_gauge_value: expected_gauge_value}
  end