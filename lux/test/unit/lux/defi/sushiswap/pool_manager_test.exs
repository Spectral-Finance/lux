defmodule Lux.Defi.SushiSwap.PoolManagerTest do
  use UnitCase, async: true

  alias Lux.Defi.SushiSwap.PoolManager

  describe "get_deployment/1" do
    test "retrieves deployment for Ethereum (1), Arbitrum (42161), Polygon (137)" do
      for chain_id <- [1, 42161, 137, 10, 8453] do
        assert {:ok, dep} = PoolManager.get_deployment(chain_id)
        assert dep.chain_id == chain_id
        assert String.starts_with?(dep.sushixswap, "0x")
      end
    end

    test "returns error on unsupported chain" do
      assert {:error, :unsupported_chain} = PoolManager.get_deployment(999999)
    end
  end

  describe "build_pool/6" do
    test "constructs pool state and computes mid price" do
      pool = PoolManager.build_pool(1, :v2, "WETH", "USDC", 1000.0, 2_600_000.0)

      assert pool.chain_id == 1
      assert pool.token0 == "WETH"
      assert pool.token1 == "USDC"
      assert pool.mid_price == 2600.0
      assert String.starts_with?(pool.id, "sushi_1_")
    end
  end
end
