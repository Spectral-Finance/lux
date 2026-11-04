defmodule Lux.Prisms.PancakeSwap.FarmTransactionPrismTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Prisms.PancakeSwap.FarmTransactionPrism
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @lp "0x00000000000000000000000000000000000000b1"
  @amount 2_000_000_000_000_000_000
  @ctx %{name: "TestAgent"}

  setup do
    {:ok, bsc} = PancakeSwap.chain("bsc")
    %{masterchef: bsc.masterchef_v2}
  end

  defp stake_input(extra \\ %{}) do
    Map.merge(%{chain: "bsc", action: "stake", pool_id: 2, owner: @owner, amount: @amount}, extra)
  end

  defp stub_allowance(allowance) do
    PancakeSwapRpc.stub(%{
      "lpToken(uint256)" => {["address"], [@lp]},
      "allowance(address,address)" => {["uint256"], [allowance]}
    })
  end

  describe "stake" do
    test "approves the LP token first when the allowance is too low", %{masterchef: masterchef} do
      stub_allowance(0)

      assert {:ok, result} = FarmTransactionPrism.handler(stake_input(), @ctx)

      assert %{
               chain: "bsc",
               chain_id: 56,
               action: "stake",
               pool_id: 2,
               steps: [approve, deposit]
             } = result

      assert approve == %{
               name: "approve",
               chain_id: 56,
               to: @lp,
               data: PancakeSwapRpc.calldata("approve(address,uint256)", [masterchef, @amount]),
               value: "0"
             }

      assert deposit == %{
               name: "deposit",
               chain_id: 56,
               to: masterchef,
               data: PancakeSwapRpc.calldata("deposit(uint256,uint256)", [2, @amount]),
               value: "0"
             }
    end

    test "skips the approval when the allowance is sufficient" do
      stub_allowance(@amount)

      assert {:ok, %{steps: [%{name: "deposit"}]}} =
               FarmTransactionPrism.handler(stake_input(), @ctx)
    end

    test "approves when the allowance is one wei short" do
      stub_allowance(@amount - 1)

      assert {:ok, %{steps: [%{name: "approve"}, %{name: "deposit"}]}} =
               FarmTransactionPrism.handler(stake_input(), @ctx)
    end

    test "checks the allowance of the owner for the masterchef", %{masterchef: masterchef} do
      stub_allowance(0)
      assert {:ok, _} = FarmTransactionPrism.handler(stake_input(), @ctx)

      expected = PancakeSwapRpc.calldata("allowance(address,address)", [@owner, masterchef])
      assert_received {:rpc_call, @lp, ^expected}
    end

    test "uses a given LP token without reading it from chain" do
      PancakeSwapRpc.stub(%{"allowance(address,address)" => {["uint256"], [0]}})
      lp = "0x00000000000000000000000000000000000000c2"

      assert {:ok, %{steps: [%{to: ^lp}, _deposit]}} =
               FarmTransactionPrism.handler(stake_input(%{lp_token: lp}), @ctx)
    end

    test "accepts the amount as a decimal string" do
      stub_allowance(@amount)

      assert {:ok, %{steps: [step]}} =
               FarmTransactionPrism.handler(
                 stake_input(%{amount: Integer.to_string(@amount)}),
                 @ctx
               )

      assert step.data == PancakeSwapRpc.calldata("deposit(uint256,uint256)", [2, @amount])
    end

    test "requires a valid owner and positive amount" do
      assert {:error, "amount must be a positive integer (wei)"} =
               FarmTransactionPrism.handler(stake_input(%{amount: 0}), @ctx)

      assert {:error, "amount must be a positive integer (wei)"} =
               FarmTransactionPrism.handler(stake_input(%{amount: "1.5"}), @ctx)

      assert {:error, "owner must be a valid 0x-prefixed Ethereum address"} =
               FarmTransactionPrism.handler(stake_input(%{owner: "nope"}), @ctx)
    end

    test "returns an error when the allowance cannot be read" do
      PancakeSwapRpc.stub(%{"lpToken(uint256)" => {["address"], [@lp]}})

      assert {:error, message} = FarmTransactionPrism.handler(stake_input(), @ctx)
      assert message =~ "Failed to read allowance"
    end
  end

  describe "harvest, unstake and emergency withdraw" do
    test "harvest is deposit(pid, 0) and needs no RPC", %{masterchef: masterchef} do
      assert {:ok, %{action: "harvest", steps: [step]}} =
               FarmTransactionPrism.handler(%{action: "harvest", pool_id: 2}, @ctx)

      assert step.name == "harvest"
      assert step.to == masterchef
      assert step.data == PancakeSwapRpc.calldata("deposit(uint256,uint256)", [2, 0])
    end

    test "unstake withdraws the amount", %{masterchef: masterchef} do
      assert {:ok, %{steps: [step]}} =
               FarmTransactionPrism.handler(%{action: "unstake", pool_id: 2, amount: "500"}, @ctx)

      assert step.name == "withdraw"
      assert step.to == masterchef
      assert step.data == PancakeSwapRpc.calldata("withdraw(uint256,uint256)", [2, 500])
    end

    test "unstake requires an amount" do
      assert {:error, "amount must be a positive integer (wei)"} =
               FarmTransactionPrism.handler(%{action: "unstake", pool_id: 2}, @ctx)
    end

    test "emergency withdraw builds emergencyWithdraw(pid)" do
      assert {:ok, %{steps: [step]}} =
               FarmTransactionPrism.handler(%{action: "emergency_withdraw", pool_id: 9}, @ctx)

      assert step.name == "emergency_withdraw"
      assert step.data == PancakeSwapRpc.calldata("emergencyWithdraw(uint256)", [9])
    end
  end

  describe "validation" do
    test "rejects unknown actions" do
      assert {:error, message} = FarmTransactionPrism.handler(%{action: "burn", pool_id: 1}, @ctx)
      assert message =~ "Unknown action"
      assert {:error, _} = FarmTransactionPrism.handler(%{pool_id: 1}, @ctx)
    end

    test "rejects invalid pool ids" do
      assert {:error, "pool_id must be a non-negative integer"} =
               FarmTransactionPrism.handler(%{action: "harvest", pool_id: "2"}, @ctx)
    end

    test "rejects unsupported chains and chains without a masterchef" do
      assert {:error, message} =
               FarmTransactionPrism.handler(
                 %{action: "harvest", pool_id: 1, chain: "solana"},
                 @ctx
               )

      assert message =~ "Unsupported chain"

      assert {:error, message} =
               FarmTransactionPrism.handler(%{action: "harvest", pool_id: 1, chain: "base"}, @ctx)

      assert message =~ "not configured for base"
    end

    test "builds steps on other chains with a masterchef override" do
      masterchef = "0x00000000000000000000000000000000000000dd"

      assert {:ok, %{chain: "base", chain_id: 8453, steps: [%{chain_id: 8453, to: ^masterchef}]}} =
               FarmTransactionPrism.handler(
                 %{action: "harvest", pool_id: 1, chain: "base", masterchef: masterchef},
                 @ctx
               )
    end
  end
end
