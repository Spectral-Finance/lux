defmodule Lux.Prisms.PancakeSwap.FarmingFlowTest do
  @moduledoc """
  Offline end-to-end tests of the farming operations: read a pool, stake, track the
  position, compound the rewards and plan a cross-chain move, all against one mocked RPC.
  """
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Prisms.PancakeSwap.ApyOptimizerPrism
  alias Lux.Prisms.PancakeSwap.AutoCompoundPrism
  alias Lux.Prisms.PancakeSwap.CrossChainPlanPrism
  alias Lux.Prisms.PancakeSwap.FarmTransactionPrism
  alias Lux.Prisms.PancakeSwap.PoolInfoPrism
  alias Lux.Prisms.PancakeSwap.PositionsPrism
  alias Lux.Prisms.PancakeSwap.RiskMonitorPrism
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @pair "0x00000000000000000000000000000000000000c3"
  @token_b "0x00000000000000000000000000000000000000b2"
  @cake 1_000_000_000_000_000_000
  @ctx %{name: "TestAgent"}

  setup do
    {:ok, bsc} = PancakeSwap.chain("bsc")

    PancakeSwapRpc.stub(%{
      "poolLength()" => {["uint256"], [10]},
      "lpToken(uint256)" => {["address"], [@pair]},
      "poolInfo(uint256)" =>
        {["uint256", "uint256", "uint256", "uint256", "bool"], [0, 0, 1_000, 5_000, true]},
      "totalRegularAllocPoint()" => {["uint256"], [10_000]},
      "cakePerBlock(bool)" => {["uint256"], [@cake]},
      "userInfo(uint256,address)" => {["uint256", "uint256", "uint256"], [3 * @cake, 0, 100]},
      "pendingCake(uint256,address)" => {["uint256"], [10 * @cake]},
      "allowance(address,address)" => {["uint256"], [0]},
      "token0()" => {["address"], [String.downcase(bsc.cake)]},
      "token1()" => {["address"], [@token_b]},
      "getReserves()" =>
        {["uint112", "uint112", "uint32"], [1_000 * @cake, 200_000_000, 1_700_000_000]},
      "totalSupply()" => {["uint256"], [1_000_000 * @cake]},
      "getAmountsOut(uint256,address[])" => {["uint256[]"], [[5 * @cake, 1_000_000]]}
    })

    :ok
  end

  test "pool -> stake -> position -> compound on BNB Smart Chain" do
    # 1. read the pool and its APR
    assert {:ok, pool} =
             PoolInfoPrism.handler(
               %{chain: "bsc", pool_id: 2, cake_price_usd: 2.0, pool_tvl_usd: 4_204_800},
               @ctx
             )

    assert_in_delta pool.apr, 0.5, 1.0e-9
    assert pool.lp_token == @pair

    # 2. build the stake transaction for 3 LP tokens
    assert {:ok, %{steps: [approve, deposit]}} =
             FarmTransactionPrism.handler(
               %{chain: "bsc", action: "stake", pool_id: 2, owner: @owner, amount: 3 * @cake},
               @ctx
             )

    assert approve.to == pool.lp_token
    assert deposit.to == pool.masterchef

    # 3. track the position
    assert {:ok, positions} =
             PositionsPrism.handler(
               %{address: @owner, positions: [%{chain: "bsc", pool_id: 2}]},
               @ctx
             )

    assert positions.total_pending_cake == Integer.to_string(10 * @cake)
    assert [%{staked: staked}] = positions.positions
    assert staked == Integer.to_string(3 * @cake)

    # 4. compound the pending rewards
    assert {:ok, compound} =
             AutoCompoundPrism.handler(
               %{
                 chain: "bsc",
                 pool_id: 2,
                 owner: @owner,
                 pending_cake: positions.total_pending_cake,
                 cake_price_usd: 2.0,
                 gas_cost_usd: 0.5
               },
               @ctx
             )

    assert compound.should_compound
    assert List.first(compound.steps).name == "harvest"
    assert List.last(compound.steps).name == "deposit"

    # 5. check the risk of the position
    assert {:ok, risk} =
             RiskMonitorPrism.handler(
               %{pool_tvl_usd: 4_204_800, position_usd: 6, cake_per_block: pool.cake_per_block},
               @ctx
             )

    assert risk.risk_level == "low"
  end

  test "multi-chain positions feed the APY optimizer and the cross-chain planner" do
    base_masterchef = "0x00000000000000000000000000000000000000dd"

    assert {:ok, positions} =
             PositionsPrism.handler(
               %{
                 address: @owner,
                 positions: [
                   %{chain: "bsc", pool_id: 2},
                   %{chain: "base", pool_id: 1, masterchef: base_masterchef}
                 ]
               },
               @ctx
             )

    assert positions.positions_ok == 2

    assert positions.pending_cake_by_chain == %{
             "bsc" => Integer.to_string(10 * @cake),
             "base" => Integer.to_string(10 * @cake)
           }

    # position values and pool APRs (priced off chain) per chain
    chains = [
      %{chain: "bsc", apr: 0.12, position_usd: 20_000},
      %{chain: "base", apr: 0.35, position_usd: 0}
    ]

    assert {:ok, apy} =
             ApyOptimizerPrism.handler(
               %{
                 pools: Enum.map(chains, &%{id: &1.chain, apr: &1.apr}),
                 position_usd: 20_000,
                 gas_cost_usd: 0.5
               },
               @ctx
             )

    assert apy.best_pool == "base"

    assert {:ok, plan} = CrossChainPlanPrism.handler(%{chains: chains, bridge_fee_usd: 10}, @ctx)

    assert plan.recommended
    assert plan.best_chain == "base"
    assert [%{from_chain: "bsc", to_chain: "base", steps: [%{type: "bridge"}]}] = plan.moves
  end
end
