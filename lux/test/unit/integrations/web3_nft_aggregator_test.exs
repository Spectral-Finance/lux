defmodule Lux.Integrations.Web3.NftAggregatorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.NftAggregator

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.NftAggregator.process(%{})
    assert {:ok, %{verified: true, issue: 87}} = Web3.NftAggregator.process(%{active: true})
    assert {:ok, 95.0} = Web3.NftAggregator.compute_efficiency_score(100, 100, 500)
  end
end
