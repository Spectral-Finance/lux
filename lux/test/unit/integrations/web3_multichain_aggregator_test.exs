defmodule Lux.Integrations.Web3.MultiChainAggregatorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.MultiChainAggregator

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.MultiChainAggregator.process(%{})
    assert {:ok, %{verified: true, issue: 74}} = Web3.MultiChainAggregator.process(%{active: true})
    assert {:ok, 95.0} = Web3.MultiChainAggregator.compute_efficiency_score(100, 100, 500)
  end
end
