defmodule Lux.Lenses.Curve.CurvePoolLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Curve.CurvePoolLens

  test "optimizes yield for curve pool data", %{mock: mock} do
    result = CurvePoolLens.fetch(mock)
    assert result == {:ok, %{data: "mock_data"}}
    assert_receive :yield_optimized
  end

  setup do
      mock = %{
        fetch: fn _ -> {:ok, %{data: "mock_data"}} end,
        yield_optimize: fn _ -> send(self(), :yield_optimized) end
      }
      {:ok, mock: mock}
    end
end

setup do
    mock = %{
      fetch: fn _ -> {:ok, %{data: "mock_data"}} end
    }
    {:ok, mock: mock}
  end

  test "fetches curve pool data", %{mock: mock} do
    result = CurvePoolLens.fetch(mock)
    assert result == {:ok, %{data: "mock_data"}}
  end