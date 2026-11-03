defmodule Lux.Integrations.Web3.GasOptimizerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.GasOptimizer

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.GasOptimizer.process(%{})
    assert {:ok, %{verified: true, issue: 76}} = Web3.GasOptimizer.process(%{active: true})
    assert {:ok, 95.0} = Web3.GasOptimizer.compute_efficiency_score(100, 100, 500)
  end
end
