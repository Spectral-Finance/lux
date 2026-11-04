defmodule Lux.Prisms.PancakeSwap.AutoCompoundPrismTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Prisms.PancakeSwap.AutoCompoundPrism
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @pair "0x00000000000000000000000000000000000000c3"
  @token_a "0x00000000000000000000000000000000000000a1"
  @token_b "0x00000000000000000000000000000000000000b2"
  @wbnb "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c"
  @deadline 1_900_000_000
  @cake 1_000_000_000_000_000_000
  @ctx %{name: "TestAgent"}

  @swap_signature "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)"
  @add_signature "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)"

  setup do
    {:ok, bsc} = PancakeSwap.chain("bsc")
    %{cake: bsc.cake, masterchef: bsc.masterchef_v2, router: bsc.router_v2}
  end

  defp input(extra \\ %{}) do
    Map.merge(
      %{
        chain: "bsc",
        pool_id: 2,
        owner: @owner,
        pending_cake: 10 * @cake,
        cake_price_usd: 2.0,
        gas_cost_usd: 1.0,
        deadline: @deadline
      },
      extra
    )
  end

  # Pair of CAKE (token0) and token B (token1)
  defp stub_cake_pair(cake, overrides \\ %{}) do
    stub_pair(String.downcase(cake), @token_b, overrides)
  end

  defp stub_pair(token0, token1, overrides \\ %{}) do
    %{
      "lpToken(uint256)" => {["address"], [@pair]},
      "token0()" => {["address"], [token0]},
      "token1()" => {["address"], [token1]},
      "getReserves()" =>
        {["uint112", "uint112", "uint32"], [1_000 * @cake, 200_000_000, 1_700_000_000]},
      "totalSupply()" => {["uint256"], [1_000_000 * @cake]},
      "getAmountsOut(uint256,address[])" => {["uint256[]"], [[5 * @cake, 1_000_000]]},
      "allowance(address,address)" => {["uint256"], [0]}
    }
    |> Map.merge(overrides)
    |> PancakeSwapRpc.stub()
  end

  describe "decision" do
    test "skips compounding when the reward does not cover the gas cost" do
      # 0.1 CAKE * $2 = $0.20 < 3 * $1
      assert {:ok, result} =
               AutoCompoundPrism.handler(input(%{pending_cake: @cake |> div(10)}), @ctx)

      assert result.should_compound == false
      assert result.steps == []
      assert result.reason =~ "below 3x the gas cost"
      assert_in_delta result.reward_usd, 0.2, 1.0e-9
      assert result.pending_cake == Integer.to_string(div(@cake, 10))
      refute_received {:rpc_call, _, _}
    end

    test "compounds exactly at the profit threshold", %{cake: cake} do
      stub_cake_pair(cake)
      # 1.5 CAKE * $2 = $3 = 3 * $1
      assert {:ok, %{should_compound: true}} =
               AutoCompoundPrism.handler(input(%{pending_cake: (3 * @cake) |> div(2)}), @ctx)
    end

    test "honours min_profit_ratio" do
      # $20 reward, gas $1 -> ratio 25 is not met
      assert {:ok, %{should_compound: false, min_profit_ratio: 25}} =
               AutoCompoundPrism.handler(input(%{min_profit_ratio: 25}), @ctx)
    end

    test "does nothing without pending rewards" do
      assert {:ok, %{should_compound: false, steps: [], reason: "No pending CAKE to compound"}} =
               AutoCompoundPrism.handler(input(%{pending_cake: 0}), @ctx)
    end

    test "reads the pending reward from chain when not given", %{masterchef: masterchef} do
      PancakeSwapRpc.stub(%{"pendingCake(uint256,address)" => {["uint256"], [0]}})

      assert {:ok, %{should_compound: false, pending_cake: "0"}} =
               AutoCompoundPrism.handler(Map.delete(input(), :pending_cake), @ctx)

      expected = PancakeSwapRpc.calldata("pendingCake(uint256,address)", [2, @owner])
      assert_received {:rpc_call, to, ^expected}
      assert String.downcase(to) == String.downcase(masterchef)
    end
  end

  describe "plan with a CAKE pair" do
    test "harvests, swaps half, adds liquidity and restakes", ctx do
      stub_cake_pair(ctx.cake)

      assert {:ok, result} = AutoCompoundPrism.handler(input(), @ctx)

      assert result.should_compound
      assert result.lp_token == @pair
      assert result.chain_id == 56

      assert Enum.map(result.steps, & &1.name) ==
               [
                 "harvest",
                 "approve",
                 "swap_token1",
                 "approve",
                 "add_liquidity",
                 "approve",
                 "deposit"
               ]

      [harvest, approve_cake, swap, approve_b, add, approve_lp, deposit] = result.steps

      assert harvest.to == ctx.masterchef
      assert harvest.data == PancakeSwapRpc.calldata("deposit(uint256,uint256)", [2, 0])

      # CAKE is approved for the whole reward: half is swapped, half is added directly
      assert approve_cake.to == ctx.cake

      assert approve_cake.data ==
               PancakeSwapRpc.calldata("approve(address,uint256)", [ctx.router, 10 * @cake])

      # quote is 1_000_000 token B for 5 CAKE; minimum after 0.5% slippage
      assert swap.to == ctx.router

      assert swap.data ==
               PancakeSwapRpc.calldata(@swap_signature, [
                 5 * @cake,
                 995_000,
                 [ctx.cake, @token_b],
                 @owner,
                 @deadline
               ])

      assert approve_b.to == @token_b

      assert approve_b.data ==
               PancakeSwapRpc.calldata("approve(address,uint256)", [ctx.router, 995_000])

      assert add.to == ctx.router

      assert add.data ==
               PancakeSwapRpc.calldata(@add_signature, [
                 ctx.cake,
                 @token_b,
                 5 * @cake,
                 995_000,
                 div(5 * @cake * 9_950, 10_000),
                 990_025,
                 @owner,
                 @deadline
               ])

      # estimated LP = min(5e18 * ts / r0, 995_000 * ts / r1), then 0.5% slippage
      total_supply = 1_000_000 * @cake

      estimated =
        min(
          div(5 * @cake * total_supply, 1_000 * @cake),
          div(995_000 * total_supply, 200_000_000)
        )

      lp_amount = div(estimated * 9_950, 10_000)

      assert result.estimated_lp == Integer.to_string(lp_amount)
      assert approve_lp.to == @pair

      assert approve_lp.data ==
               PancakeSwapRpc.calldata("approve(address,uint256)", [ctx.masterchef, lp_amount])

      assert deposit.to == ctx.masterchef
      assert deposit.data == PancakeSwapRpc.calldata("deposit(uint256,uint256)", [2, lp_amount])
    end

    test "omits approvals that are already in place", ctx do
      stub_cake_pair(ctx.cake, %{
        "allowance(address,address)" => {["uint256"], [Integer.pow(2, 255)]}
      })

      assert {:ok, result} = AutoCompoundPrism.handler(input(), @ctx)

      assert Enum.map(result.steps, & &1.name) == [
               "harvest",
               "swap_token1",
               "add_liquidity",
               "deposit"
             ]
    end

    test "works when CAKE is token1 of the pair", ctx do
      stub_pair(@token_a, String.downcase(ctx.cake))

      assert {:ok, result} = AutoCompoundPrism.handler(input(), @ctx)

      assert Enum.map(result.steps, & &1.name) ==
               [
                 "harvest",
                 "approve",
                 "swap_token0",
                 "approve",
                 "add_liquidity",
                 "approve",
                 "deposit"
               ]
    end
  end

  describe "plan with a pair that does not contain CAKE" do
    test "swaps both halves", ctx do
      stub_pair(@token_a, @token_b)

      assert {:ok, result} = AutoCompoundPrism.handler(input(), @ctx)

      assert Enum.map(result.steps, & &1.name) ==
               [
                 "harvest",
                 "approve",
                 "swap_token0",
                 "swap_token1",
                 "approve",
                 "approve",
                 "add_liquidity",
                 "approve",
                 "deposit"
               ]

      swap0 = Enum.find(result.steps, &(&1.name == "swap_token0"))

      assert swap0.data ==
               PancakeSwapRpc.calldata(@swap_signature, [
                 5 * @cake,
                 995_000,
                 [ctx.cake, @token_a],
                 @owner,
                 @deadline
               ])
    end

    test "uses a custom swap path", ctx do
      stub_pair(@token_a, @token_b)

      assert {:ok, result} =
               AutoCompoundPrism.handler(input(%{path_token1: [ctx.cake, @wbnb, @token_b]}), @ctx)

      swap1 = Enum.find(result.steps, &(&1.name == "swap_token1"))

      assert swap1.data ==
               PancakeSwapRpc.calldata(@swap_signature, [
                 5 * @cake,
                 995_000,
                 [ctx.cake, @wbnb, @token_b],
                 @owner,
                 @deadline
               ])
    end

    test "rejects a swap path that does not end in the pair token", ctx do
      stub_pair(@token_a, @token_b)

      assert {:error, message} =
               AutoCompoundPrism.handler(input(%{path_token1: [ctx.cake, @wbnb]}), @ctx)

      assert message =~ "path_token1 must be a list of addresses from CAKE"

      assert {:error, "path_token1 must be a list of at least two addresses"} =
               AutoCompoundPrism.handler(input(%{path_token1: "nope"}), @ctx)
    end
  end

  describe "errors" do
    test "fails when a swap cannot be quoted", ctx do
      stub_cake_pair(ctx.cake, %{
        "getAmountsOut(uint256,address[])" => {:error, -32_000, "execution reverted"}
      })

      assert {:error, message} = AutoCompoundPrism.handler(input(), @ctx)
      assert message =~ "Failed to read swap quote for token1"
    end

    test "fails when the pair has no liquidity", ctx do
      stub_cake_pair(ctx.cake, %{
        "getReserves()" => {["uint112", "uint112", "uint32"], [0, 0, 0]}
      })

      assert {:error, message} = AutoCompoundPrism.handler(input(), @ctx)
      assert message =~ "no liquidity"
    end

    test "fails when the reward is too small to mint any LP", ctx do
      stub_cake_pair(ctx.cake, %{"totalSupply()" => {["uint256"], [0]}})

      assert {:error, message} = AutoCompoundPrism.handler(input(), @ctx)
      assert message =~ "LP amount is zero"
    end

    test "validates the input" do
      assert {:error, "pool_id must be a non-negative integer"} =
               AutoCompoundPrism.handler(input(%{pool_id: nil}), @ctx)

      assert {:error, "owner must be a valid 0x-prefixed Ethereum address"} =
               AutoCompoundPrism.handler(input(%{owner: "nope"}), @ctx)

      assert {:error, "cake_price_usd must be a positive number"} =
               AutoCompoundPrism.handler(input(%{cake_price_usd: 0}), @ctx)

      assert {:error, "gas_cost_usd must be a non-negative number"} =
               AutoCompoundPrism.handler(input(%{gas_cost_usd: -1}), @ctx)

      assert {:error, "pending_cake must be a non-negative integer (wei)"} =
               AutoCompoundPrism.handler(input(%{pending_cake: "abc"}), @ctx)

      assert {:error, "slippage_bps must be an integer between 0 and 10000"} =
               AutoCompoundPrism.handler(input(%{slippage_bps: 20_000}), @ctx)

      assert {:error, message} = AutoCompoundPrism.handler(input(%{chain: "solana"}), @ctx)
      assert message =~ "Unsupported chain"

      assert {:error, message} = AutoCompoundPrism.handler(input(%{chain: "base"}), @ctx)
      assert message =~ "masterchef_v2 contract is not configured for base"
    end
  end
end
