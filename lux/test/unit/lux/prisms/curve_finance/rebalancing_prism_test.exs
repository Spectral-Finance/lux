defmodule Lux.Prisms.CurveFinance.RebalancingPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.CurveFinance.RebalancingPrism

  describe "run/1" do
    test "determines rebalance action" do
      params = %{current_pool: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7", target_pool: "0xa5407eae9ba41425113d2f07db54d6d49899ae69", threshold: 0.01}
      assert {:ok, result} = RebalancingPrism.run(params)
      assert result.action in [:hold, :rebalance]
    end

    test "includes gas cost analysis" do
      params = %{current_pool: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7", target_pool: "0xa5407eae9ba41425113d2f07db54d6d49899ae69", include_gas: true}
      assert {:ok, result} = RebalancingPrism.run(params)
      assert result.gas_costs.total >= 0
    end
  end
end
