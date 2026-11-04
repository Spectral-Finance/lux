defmodule Lux.Prisms.PancakeSwap.PoolInfoPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.PancakeSwap.PoolInfoPrism
  alias Test.Support.PancakeSwapRpc

  @lp "0x00000000000000000000000000000000000000b1"
  @cake 1_000_000_000_000_000_000
  @ctx %{name: "TestAgent"}

  defp stub_pool(overrides \\ %{}) do
    %{
      "poolLength()" => {["uint256"], [10]},
      "lpToken(uint256)" => {["address"], [@lp]},
      "poolInfo(uint256)" =>
        {["uint256", "uint256", "uint256", "uint256", "bool"], [0, 0, 1_000, 5_000, true]},
      "totalRegularAllocPoint()" => {["uint256"], [10_000]},
      "totalSpecialAllocPoint()" => {["uint256"], [500]},
      "cakePerBlock(bool)" => {["uint256"], [@cake]}
    }
    |> Map.merge(overrides)
    |> PancakeSwapRpc.stub()
  end

  describe "handler/2" do
    test "reads the pool and computes the yearly emission" do
      stub_pool()

      assert {:ok, pool} = PoolInfoPrism.handler(%{chain: "bsc", pool_id: 2}, @ctx)

      assert pool.chain == "bsc"
      assert pool.chain_id == 56
      assert pool.pool_id == 2
      assert pool.pool_length == 10
      assert pool.lp_token == @lp
      assert pool.is_regular
      assert pool.alloc_point == 1_000
      assert pool.total_alloc_point == 10_000
      assert pool.total_boosted_share == "5000"
      assert pool.cake_per_block == Integer.to_string(@cake)
      # 1 CAKE/block * 1000/10000 * 10_512_000 blocks = 1_051_200 CAKE
      assert pool.cake_per_year == Integer.to_string(1_051_200 * @cake)
      refute Map.has_key?(pool, :apr)
    end

    test "defaults to the bsc chain and accepts string keys" do
      stub_pool()
      assert {:ok, %{chain: "bsc"}} = PoolInfoPrism.handler(%{"pool_id" => 2}, @ctx)
    end

    test "computes the APR when prices are given" do
      stub_pool()

      assert {:ok, pool} =
               PoolInfoPrism.handler(
                 %{pool_id: 2, cake_price_usd: 2.0, pool_tvl_usd: 4_204_800},
                 @ctx
               )

      assert_in_delta pool.apr, 0.5, 1.0e-9
    end

    test "honours a custom blocks_per_year" do
      stub_pool()

      assert {:ok, pool} = PoolInfoPrism.handler(%{pool_id: 2, blocks_per_year: 1_000}, @ctx)
      # 1 CAKE * 1000/10000 * 1000 blocks = 100 CAKE
      assert pool.cake_per_year == Integer.to_string(100 * @cake)
    end

    test "uses the special allocation for non regular pools" do
      stub_pool(%{
        "poolInfo(uint256)" =>
          {["uint256", "uint256", "uint256", "uint256", "bool"], [0, 0, 250, 0, false]}
      })

      assert {:ok, pool} = PoolInfoPrism.handler(%{pool_id: 3, blocks_per_year: 100}, @ctx)

      refute pool.is_regular
      assert pool.total_alloc_point == 500
      # 1 CAKE * 250/500 * 100 blocks = 50 CAKE
      assert pool.cake_per_year == Integer.to_string(50 * @cake)
    end

    test "handles a pool without allocation points" do
      stub_pool(%{"totalRegularAllocPoint()" => {["uint256"], [0]}})
      assert {:ok, %{cake_per_year: "0"}} = PoolInfoPrism.handler(%{pool_id: 2}, @ctx)
    end

    test "returns an error for a pool id that does not exist" do
      stub_pool()
      assert {:error, message} = PoolInfoPrism.handler(%{pool_id: 10}, @ctx)
      assert message =~ "does not exist"
    end

    test "validates the input" do
      assert {:error, "pool_id must be a non-negative integer"} =
               PoolInfoPrism.handler(%{pool_id: -1}, @ctx)

      assert {:error, "pool_id must be a non-negative integer"} = PoolInfoPrism.handler(%{}, @ctx)
      assert {:error, message} = PoolInfoPrism.handler(%{chain: "solana", pool_id: 1}, @ctx)
      assert message =~ "Unsupported chain"
    end

    test "reports chains without a MasterChef" do
      assert {:error, message} = PoolInfoPrism.handler(%{chain: "base", pool_id: 1}, @ctx)
      assert message =~ "masterchef_v2 contract is not configured for base"
    end

    test "uses a MasterChef override on other chains" do
      stub_pool()
      masterchef = "0x00000000000000000000000000000000000000aa"

      assert {:ok, %{chain: "base", masterchef: ^masterchef}} =
               PoolInfoPrism.handler(%{chain: "base", pool_id: 1, masterchef: masterchef}, @ctx)

      assert_received {:rpc_call, ^masterchef, _data}
    end

    test "returns RPC errors as strings" do
      PancakeSwapRpc.stub(%{})

      assert {:error, "RPC error -32000: execution reverted"} =
               PoolInfoPrism.handler(%{pool_id: 2}, @ctx)
    end
  end

  describe "view/0" do
    test "exposes the schema" do
      prism = PoolInfoPrism.view()
      assert prism.name == "PancakeSwap Pool Info"
      assert prism.input_schema.required == ["pool_id"]
      assert Map.has_key?(prism.input_schema.properties, :chain)
    end
  end
end
