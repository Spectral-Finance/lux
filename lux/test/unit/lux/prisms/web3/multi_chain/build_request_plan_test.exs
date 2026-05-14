defmodule Lux.Prisms.Web3.MultiChain.BuildRequestPlanTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.MultiChain.BuildRequestPlan

  test "returns a multi-chain request plan" do
    assert {:ok, plan} =
             BuildRequestPlan.handler(
               %{chains: [:ethereum], actions: [:latest_block], filter: %{address: "0xabc"}},
               nil
             )

    assert plan.summary.request_count == 1
    assert [%{chain: :ethereum, payload: %{method: "eth_blockNumber"}}] = plan.requests
  end
end
