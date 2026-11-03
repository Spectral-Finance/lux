defmodule Lux.Defi.PancakeSwap.PoolManagerTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.PoolManager

  describe "deployment configurations" do
    test "retrieves deployment for BSC (56)" do
      {:ok, deployment} = PoolManager.get_deployment(56)
      assert deployment.chain_name == "BNB Smart Chain"
      assert deployment.chain_id == 56
      assert deployment.native_symbol == "BNB"
      assert String.starts_with?(deployment.masterchef_v3, "0x")
      assert String.starts_with?(deployment.cake_token, "0x")
    end

    test "retrieves deployment for Ethereum (1), Arbitrum (42161), and Base (8453)" do
      for chain_id <- [1, 42161, 8453] do
        assert {:ok, config} = PoolManager.get_deployment(chain_id)
        assert config.chain_id == chain_id
      end
    end

    test "lists all supported deployments" do
      deployments = PoolManager.list_deployments()
      assert length(deployments) == 4
    end

    test "returns error for unsupported chain" do
      assert {:error, :unsupported_chain} = PoolManager.get_deployment(999999)
    end
  end

  describe "build_pool/1" do
    test "creates pool state successfully" do
      params = %{
        chain_id: 56,
        pool_type: :v3,
        token0: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
        token1: "0x55d398326f99059fF775485246999027B3197955",
        fee: 2500,
        pool_address: "0x36696169C63e42cd08ce11f5deeBbCeBae652050"
      }

      assert {:ok, pool} = PoolManager.build_pool(params)
      assert pool.chain_id == 56
      assert pool.pool_type == :v3
      assert pool.fee == 2500
      assert String.starts_with?(pool.id, "pcs_56_")
    end

    test "fails with missing token" do
      params = %{chain_id: 56, token0: "0x123"}
      assert {:error, :missing_tokens} = PoolManager.build_pool(params)
    end
  end
end
