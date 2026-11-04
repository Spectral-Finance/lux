defmodule Lux.Prisms.PancakeSwap.LiquidityTransactionPrismTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Prisms.PancakeSwap.LiquidityTransactionPrism
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @token_a "0x00000000000000000000000000000000000000a1"
  @token_b "0x00000000000000000000000000000000000000b2"
  @pair "0x00000000000000000000000000000000000000c3"
  @deadline 1_900_000_000
  @ctx %{name: "TestAgent"}

  @add_signature "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)"
  @remove_signature "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)"

  setup do
    {:ok, bsc} = PancakeSwap.chain("bsc")
    %{router: bsc.router_v2}
  end

  defp add_input(extra \\ %{}) do
    Map.merge(
      %{
        chain: "bsc",
        action: "add",
        owner: @owner,
        token_a: @token_a,
        token_b: @token_b,
        amount_a_desired: 1_000,
        amount_b_desired: "500",
        deadline: @deadline
      },
      extra
    )
  end

  defp remove_input(extra \\ %{}) do
    Map.merge(
      %{
        chain: "bsc",
        action: "remove",
        owner: @owner,
        token_a: @token_a,
        token_b: @token_b,
        liquidity: 200,
        expected_amount_a: 1_000,
        expected_amount_b: 500,
        lp_token: @pair,
        deadline: @deadline
      },
      extra
    )
  end

  defp stub_allowance(allowance),
    do: PancakeSwapRpc.stub(%{"allowance(address,address)" => {["uint256"], [allowance]}})

  describe "add" do
    test "approves both tokens and adds liquidity with slippage protected minimums", %{
      router: router
    } do
      stub_allowance(0)

      assert {:ok, result} = LiquidityTransactionPrism.handler(add_input(), @ctx)

      assert %{chain: "bsc", chain_id: 56, action: "add", slippage_bps: 50, deadline: @deadline} =
               result

      assert [approve_a, approve_b, add] = result.steps

      assert approve_a.name == "approve"
      assert approve_a.to == @token_a

      assert approve_a.data ==
               PancakeSwapRpc.calldata("approve(address,uint256)", [router, 1_000])

      assert approve_b.to == @token_b
      assert approve_b.data == PancakeSwapRpc.calldata("approve(address,uint256)", [router, 500])

      assert add.name == "add_liquidity"
      assert add.to == router

      # minimums: 1000 * 0.995 = 995 and 500 * 0.995 = 497.5 -> 497
      assert add.data ==
               PancakeSwapRpc.calldata(@add_signature, [
                 @token_a,
                 @token_b,
                 1_000,
                 500,
                 995,
                 497,
                 @owner,
                 @deadline
               ])
    end

    test "only adds liquidity when the allowances are sufficient" do
      stub_allowance(1_000_000)

      assert {:ok, %{steps: [%{name: "add_liquidity"}]}} =
               LiquidityTransactionPrism.handler(add_input(), @ctx)
    end

    test "honours slippage_bps and a custom recipient", %{router: router} do
      stub_allowance(1_000_000)
      recipient = "0x00000000000000000000000000000000000000ee"

      assert {:ok, %{slippage_bps: 100, steps: [add]}} =
               LiquidityTransactionPrism.handler(
                 add_input(%{slippage_bps: 100, recipient: recipient}),
                 @ctx
               )

      assert add.to == router

      assert add.data ==
               PancakeSwapRpc.calldata(@add_signature, [
                 @token_a,
                 @token_b,
                 1_000,
                 500,
                 990,
                 495,
                 recipient,
                 @deadline
               ])
    end

    test "derives the deadline from :now when none is given" do
      stub_allowance(1_000_000)

      assert {:ok, %{deadline: 5_200}} =
               LiquidityTransactionPrism.handler(add_input(%{deadline: nil, now: 4_000}), @ctx)
    end

    test "validates amounts, tokens and slippage" do
      assert {:error, "amount_a_desired must be a positive integer (wei)"} =
               LiquidityTransactionPrism.handler(add_input(%{amount_a_desired: 0}), @ctx)

      assert {:error, "amount_b_desired must be a positive integer (wei)"} =
               LiquidityTransactionPrism.handler(add_input(%{amount_b_desired: nil}), @ctx)

      assert {:error, "token_a must be a valid 0x-prefixed Ethereum address"} =
               LiquidityTransactionPrism.handler(add_input(%{token_a: "nope"}), @ctx)

      assert {:error, "owner must be a valid 0x-prefixed Ethereum address"} =
               LiquidityTransactionPrism.handler(add_input(%{owner: nil}), @ctx)

      assert {:error, "token_a and token_b must be different tokens"} =
               LiquidityTransactionPrism.handler(
                 add_input(%{
                   token_b: "0x" <> String.upcase(String.trim_leading(@token_a, "0x"))
                 }),
                 @ctx
               )

      assert {:error, "slippage_bps must be an integer between 0 and 10000"} =
               LiquidityTransactionPrism.handler(add_input(%{slippage_bps: 10_001}), @ctx)

      assert {:error, "recipient must be a valid 0x-prefixed Ethereum address"} =
               LiquidityTransactionPrism.handler(add_input(%{recipient: "nope"}), @ctx)
    end

    test "rejects unknown actions and chains" do
      assert {:error, message} =
               LiquidityTransactionPrism.handler(add_input(%{action: "swap"}), @ctx)

      assert message =~ "Unknown action"

      assert {:error, message} =
               LiquidityTransactionPrism.handler(add_input(%{chain: "solana"}), @ctx)

      assert message =~ "Unsupported chain"
    end

    test "uses the router of the requested chain" do
      stub_allowance(1_000_000)
      {:ok, base} = PancakeSwap.chain("base")

      assert {:ok, %{chain_id: 8453, steps: [%{chain_id: 8453, to: router}]}} =
               LiquidityTransactionPrism.handler(add_input(%{chain: "base"}), @ctx)

      assert router == base.router_v2
    end
  end

  describe "remove" do
    test "approves the LP token and removes liquidity", %{router: router} do
      stub_allowance(0)

      assert {:ok, %{action: "remove", steps: [approve, remove]}} =
               LiquidityTransactionPrism.handler(remove_input(), @ctx)

      assert approve.to == @pair
      assert approve.data == PancakeSwapRpc.calldata("approve(address,uint256)", [router, 200])

      assert remove.name == "remove_liquidity"
      assert remove.to == router

      assert remove.data ==
               PancakeSwapRpc.calldata(@remove_signature, [
                 @token_a,
                 @token_b,
                 200,
                 995,
                 497,
                 @owner,
                 @deadline
               ])
    end

    test "looks the pair up through the factory when no lp_token is given" do
      PancakeSwapRpc.stub(%{
        "getPair(address,address)" => {["address"], [@pair]},
        "allowance(address,address)" => {["uint256"], [200]}
      })

      assert {:ok, %{steps: [%{name: "remove_liquidity"}]}} =
               LiquidityTransactionPrism.handler(remove_input(%{lp_token: nil}), @ctx)

      expected = PancakeSwapRpc.calldata("getPair(address,address)", [@token_a, @token_b])
      assert_received {:rpc_call, _factory, ^expected}
      assert_received {:rpc_call, @pair, _allowance_call}
    end

    test "fails when the pair does not exist" do
      PancakeSwapRpc.stub(%{
        "getPair(address,address)" =>
          {["address"], ["0x0000000000000000000000000000000000000000"]}
      })

      assert {:error, message} =
               LiquidityTransactionPrism.handler(remove_input(%{lp_token: nil}), @ctx)

      assert message =~ "No PancakeSwap V2 pair exists"
    end

    test "requires liquidity and expected amounts" do
      assert {:error, "liquidity must be a positive integer (wei)"} =
               LiquidityTransactionPrism.handler(remove_input(%{liquidity: 0}), @ctx)

      assert {:error, "expected_amount_a must be a positive integer (wei)"} =
               LiquidityTransactionPrism.handler(remove_input(%{expected_amount_a: nil}), @ctx)
    end
  end
end
