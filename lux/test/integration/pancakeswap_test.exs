defmodule Lux.Integration.PancakeSwapTest do
  @moduledoc """
  Read-only checks against the public BNB Smart Chain RPC. Set `PANCAKESWAP_RPC_URL` to
  use another endpoint.
  """
  use IntegrationCase, async: false

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Lux.Prisms.PancakeSwap.AutoCompoundPrism
  alias Lux.Prisms.PancakeSwap.FarmTransactionPrism
  alias Lux.Prisms.PancakeSwap.PoolInfoPrism
  alias Lux.Prisms.PancakeSwap.PositionsPrism

  @owner "0x0000000000000000000000000000000000000001"
  @ctx %{name: "IntegrationAgent"}

  setup do
    # Unit tests inject a Req.Test plug globally; make sure real requests are made here.
    Application.delete_env(:lux, Client)
    %{rpc_url: System.get_env("PANCAKESWAP_RPC_URL")}
  end

  describe "farming operations on BNB Smart Chain" do
    test "reads the pool length from the MasterChef", %{rpc_url: rpc_url} do
      {:ok, chain} = PancakeSwap.chain("bsc")

      assert {:ok, [pool_length]} =
               Client.eth_call(chain, chain.masterchef_v2, "poolLength()", [], ["uint256"],
                 rpc_url: rpc_url
               )

      assert pool_length > 0
    end

    test "reads pool information", %{rpc_url: rpc_url} do
      assert {:ok, pool} =
               PoolInfoPrism.run(%{
                 chain: "bsc",
                 pool_id: 2,
                 rpc_url: rpc_url,
                 cake_price_usd: 2.0,
                 pool_tvl_usd: 1_000_000
               })

      assert pool.pool_id == 2
      assert "0x" <> _ = pool.lp_token
      assert is_float(pool.apr)
    end

    test "reads a (empty) position", %{rpc_url: rpc_url} do
      assert {:ok, result} =
               PositionsPrism.run(%{
                 address: @owner,
                 positions: [%{chain: "bsc", pool_id: 2, rpc_url: rpc_url}]
               })

      assert result.positions_ok == 1
      assert result.total_pending_cake == "0"
    end

    test "builds a stake transaction plan", %{rpc_url: rpc_url} do
      assert {:ok, %{steps: steps}} =
               FarmTransactionPrism.run(%{
                 chain: "bsc",
                 action: "stake",
                 pool_id: 2,
                 owner: @owner,
                 amount: "1000000000000000000",
                 rpc_url: rpc_url
               })

      assert List.last(steps).name == "deposit"
    end

    test "decides not to compound an empty position", %{rpc_url: rpc_url} do
      assert {:ok, %{should_compound: false}} =
               AutoCompoundPrism.run(%{
                 chain: "bsc",
                 pool_id: 2,
                 owner: @owner,
                 cake_price_usd: 2.0,
                 gas_cost_usd: 0.5,
                 rpc_url: rpc_url
               })
    end
  end

  describe "cross-chain" do
    test "the V2 factory is deployed on every supported chain" do
      for chain_name <- PancakeSwap.supported_chains() do
        {:ok, chain} = PancakeSwap.chain(chain_name)

        assert {:ok, [pairs]} =
                 Client.eth_call(chain, chain.factory_v2, "allPairsLength()", [], ["uint256"])

        assert pairs > 0, "no pairs on #{chain_name}"
      end
    end
  end
end
