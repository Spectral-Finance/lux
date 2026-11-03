defmodule Lux.Integrations.Web3.PancakeSwapManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.PancakeSwapManager

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.PancakeSwapManager.process(%{})
    assert {:ok, %{verified: true, issue: 79}} = Web3.PancakeSwapManager.process(%{active: true})
    assert {:ok, 95.0} = Web3.PancakeSwapManager.compute_efficiency_score(100, 100, 500)
  end
end
