defmodule Lux.Prisms.PancakeSwap.PositionsPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.PancakeSwap.PositionsPrism
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @base_masterchef "0x00000000000000000000000000000000000000dd"
  @ctx %{name: "TestAgent"}

  defp farm_responses(staked, pending) do
    %{
      "userInfo(uint256,address)" => {["uint256", "uint256", "uint256"], [staked, 0, 100]},
      "pendingCake(uint256,address)" => {["uint256"], [pending]}
    }
  end

  defp entries do
    [
      %{chain: "bsc", pool_id: 2, rpc_url: "https://bsc.test/rpc"},
      %{chain: "base", pool_id: 1, masterchef: @base_masterchef, rpc_url: "https://base.test/rpc"}
    ]
  end

  describe "handler/2" do
    test "reads positions on several chains and sums the pending rewards" do
      PancakeSwapRpc.stub_hosts(%{
        "bsc.test" => farm_responses(1_000, 50),
        "base.test" => farm_responses(400, 25)
      })

      assert {:ok, result} =
               PositionsPrism.handler(%{address: @owner, positions: entries()}, @ctx)

      assert result.address == @owner
      assert result.positions_ok == 2
      assert result.positions_failed == 0
      assert result.total_pending_cake == "75"
      assert result.pending_cake_by_chain == %{"bsc" => "50", "base" => "25"}

      assert [bsc, base] = result.positions

      assert %{
               chain: "bsc",
               chain_id: 56,
               pool_id: 2,
               status: "ok",
               staked: "1000",
               pending_cake: "50"
             } = bsc

      assert %{
               chain: "base",
               chain_id: 8453,
               pool_id: 1,
               status: "ok",
               staked: "400",
               pending_cake: "25"
             } = base
    end

    test "queries userInfo and pendingCake with the wallet and pool id" do
      PancakeSwapRpc.stub(farm_responses(1, 1))

      assert {:ok, _} =
               PositionsPrism.handler(
                 %{address: @owner, positions: [%{chain: "bsc", pool_id: 7}]},
                 @ctx
               )

      user_info = PancakeSwapRpc.calldata("userInfo(uint256,address)", [7, @owner])
      pending = PancakeSwapRpc.calldata("pendingCake(uint256,address)", [7, @owner])
      assert_received {:rpc_call, _masterchef, ^user_info}
      assert_received {:rpc_call, _masterchef, ^pending}
    end

    test "a failing chain does not fail the other positions" do
      PancakeSwapRpc.stub_hosts(%{
        "bsc.test" => farm_responses(1_000, 50),
        "base.test" => %{}
      })

      assert {:ok, result} =
               PositionsPrism.handler(%{address: @owner, positions: entries()}, @ctx)

      assert result.positions_ok == 1
      assert result.positions_failed == 1
      assert result.total_pending_cake == "50"
      assert result.pending_cake_by_chain == %{"bsc" => "50"}

      assert [%{status: "ok"}, %{chain: "base", status: "error", error: error}] = result.positions
      assert error =~ "execution reverted"
    end

    test "an unreachable chain is reported as an error entry" do
      PancakeSwapRpc.stub_hosts(%{"bsc.test" => farm_responses(1_000, 50)})

      assert {:ok, result} =
               PositionsPrism.handler(%{address: @owner, positions: entries()}, @ctx)

      assert [%{status: "ok"}, %{status: "error"}] = result.positions
    end

    test "reports unsupported chains and missing contracts per entry" do
      PancakeSwapRpc.stub(farm_responses(1, 1))

      positions = [
        %{chain: "solana", pool_id: 1},
        %{chain: "base", pool_id: 1},
        %{chain: "bsc", pool_id: -1},
        "garbage"
      ]

      assert {:ok, result} =
               PositionsPrism.handler(%{address: @owner, positions: positions}, @ctx)

      assert result.positions_ok == 0
      assert result.positions_failed == 4
      assert result.total_pending_cake == "0"
      assert [one, two, three, four] = result.positions
      assert one.error =~ "Unsupported chain"
      assert two.error =~ "not configured for base"
      assert three.error =~ "pool_id must be"
      assert four.error =~ "invalid position entry"
    end

    test "validates the wallet address and the positions list" do
      assert {:error, "address must be a valid 0x-prefixed Ethereum address"} =
               PositionsPrism.handler(%{address: "nope", positions: entries()}, @ctx)

      assert {:error, "positions must be a non-empty list"} =
               PositionsPrism.handler(%{address: @owner, positions: []}, @ctx)

      assert {:error, "positions must be a non-empty list"} =
               PositionsPrism.handler(%{address: @owner}, @ctx)
    end
  end
end
