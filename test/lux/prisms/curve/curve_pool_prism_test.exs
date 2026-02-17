# Lines 1-25 of test/lux/prisms/curve/curve_pool_prism_test.exs
defmodule Test.Lux.Prisms.Curve.CurvePoolPrismTest do
  use ExUnit.Case
  alias Lux.Prisms.Curve.CurvePoolPrism

  test "integration test for curve_pool_prism" do
    # Arrange
    input = %{
      pool_id: "123",
      user_address: "0x1234567890abcdef"
    }

    # Act
    result = CurvePoolPrism.apply(input)

    # Assert
    assert result == expected_output
  end

  test "test for adding liquidity" do
    # Arrange
    input = %{
      pool_id: "123",
      user_address: "0x1234567890abcdef",
      amount: 100
    }

    # Act
    result = CurvePoolPrism.add_liquidity(input)

    # Assert
    assert result == expected_output
  end

  test "test for removing liquidity" do
    # Arrange
    input = %{
      pool_id: "123",
      user_address: "0x1234567890abcdef",
      amount: 50
    }

    # Act
    result = CurvePoolPrism.remove_liquidity(input)

    # Assert
    assert result == expected_output
  end

  setup do
    %{
      pool_id: "123",
      user_address: "0x1234567890abcdef"
    }
  end
end
