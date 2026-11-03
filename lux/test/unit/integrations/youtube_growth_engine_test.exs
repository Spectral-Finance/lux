defmodule Lux.Integrations.YouTube.GrowthEngineTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.GrowthEngine

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = YouTube.GrowthEngine.process(%{})
    assert {:ok, %{verified: true, issue: 72}} = YouTube.GrowthEngine.process(%{active: true})
    assert {:ok, 95.0} = YouTube.GrowthEngine.compute_efficiency_score(100, 100, 500)
  end
end
