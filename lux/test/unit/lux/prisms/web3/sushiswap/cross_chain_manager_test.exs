defmodule Lux.Prisms.Web3.SushiSwap.CrossChainManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.SushiSwap.CrossChainManager

  setup do
    name = :"sushi_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = CrossChainManager.start_link(name: name)
    %{pid: pid}
  end

  # --- Liquidity ---

  test "add liquidity", %{pid: pid} do
    {:ok, pool} = CrossChainManager.add_liquidity(pid, %{token0: "SUSHI", token1: "ETH", chain: :ethereum})
    assert pool.status == :active
    assert pool.chain == :ethereum
  end

  test "add liquidity missing tokens", %{pid: pid} do
    assert {:error, :missing_tokens} = CrossChainManager.add_liquidity(pid, %{chain: :ethereum})
  end

  test "add liquidity same token", %{pid: pid} do
    assert {:error, :same_token} = CrossChainManager.add_liquidity(pid, %{token0: "ETH", token1: "ETH"})
  end

  test "add liquidity unsupported chain", %{pid: pid} do
    assert {:error, :unsupported_chain} = CrossChainManager.add_liquidity(pid, %{token0: "A", token1: "B", chain: :solana})
  end

  test "remove liquidity", %{pid: pid} do
    {:ok, pool} = CrossChainManager.add_liquidity(pid, %{token0: "A", token1: "B"})
    {:ok, removed} = CrossChainManager.remove_liquidity(pid, pool.id)
    assert removed.status == :removed
  end

  test "remove already removed", %{pid: pid} do
    {:ok, pool} = CrossChainManager.add_liquidity(pid, %{token0: "A", token1: "B"})
    {:ok, _} = CrossChainManager.remove_liquidity(pid, pool.id)
    assert {:error, :already_removed} = CrossChainManager.remove_liquidity(pid, pool.id)
  end

  test "remove not found", %{pid: pid} do
    assert {:error, :not_found} = CrossChainManager.remove_liquidity(pid, "nope")
  end

  test "list pools", %{pid: pid} do
    {:ok, _} = CrossChainManager.add_liquidity(pid, %{token0: "A", token1: "B"})
    {:ok, pools} = CrossChainManager.list_pools(pid)
    assert length(pools) == 1
  end

  # --- Bridge ---

  test "initiate bridge", %{pid: pid} do
    {:ok, bridge} = CrossChainManager.initiate_bridge(pid, %{token: "USDC", amount: 1000, from_chain: :ethereum, to_chain: :arbitrum})
    assert bridge.status == :pending
    assert bridge.from_chain == :ethereum
  end

  test "bridge unsupported chain", %{pid: pid} do
    assert {:error, :unsupported_chain} = CrossChainManager.initiate_bridge(pid, %{token: "ETH", amount: 1, from_chain: :solana, to_chain: :ethereum})
  end

  test "bridge same chain", %{pid: pid} do
    assert {:error, :same_chain} = CrossChainManager.initiate_bridge(pid, %{token: "ETH", amount: 1, from_chain: :ethereum, to_chain: :ethereum})
  end

  test "bridge zero amount", %{pid: pid} do
    assert {:error, :invalid_amount} = CrossChainManager.initiate_bridge(pid, %{token: "ETH", amount: 0, from_chain: :ethereum, to_chain: :polygon})
  end

  test "bridge missing token", %{pid: pid} do
    assert {:error, :missing_token} = CrossChainManager.initiate_bridge(pid, %{amount: 100, from_chain: :ethereum, to_chain: :polygon})
  end

  test "bridge status", %{pid: pid} do
    {:ok, bridge} = CrossChainManager.initiate_bridge(pid, %{token: "ETH", amount: 1, from_chain: :ethereum, to_chain: :polygon})
    {:ok, status} = CrossChainManager.get_bridge_status(pid, bridge.id)
    assert status.status == :pending
  end

  test "bridge status not found", %{pid: pid} do
    assert {:error, :not_found} = CrossChainManager.get_bridge_status(pid, "nope")
  end

  # --- Staking ---

  test "stake sushi", %{pid: pid} do
    {:ok, s} = CrossChainManager.stake_sushi(pid, 1000)
    assert s.sushi_staked == 1000
    assert s.xsushi == 950.0
  end

  test "stake sushi accumulates", %{pid: pid} do
    {:ok, _} = CrossChainManager.stake_sushi(pid, 1000)
    {:ok, s} = CrossChainManager.stake_sushi(pid, 500)
    assert s.sushi_staked == 1500
  end

  test "stake invalid amount", %{pid: pid} do
    assert {:error, :invalid_amount} = CrossChainManager.stake_sushi(pid, 0)
    assert {:error, :invalid_amount} = CrossChainManager.stake_sushi(pid, -100)
  end

  # --- Misc ---

  test "supported chains" do
    chains = CrossChainManager.supported_chains()
    assert :ethereum in chains
    assert :arbitrum in chains
    assert length(chains) == 7
  end

  test "estimate bridge fee" do
    {:ok, est} = CrossChainManager.estimate_bridge_fee(%{amount: 1000, from_chain: :ethereum, to_chain: :arbitrum})
    assert est.fee > 0
    assert est.estimated_time_minutes == 10
    assert est.amount_received < 1000
  end

  test "estimate bridge fee same chain" do
    assert {:error, :same_chain} = CrossChainManager.estimate_bridge_fee(%{amount: 100, from_chain: :ethereum, to_chain: :ethereum})
  end

  test "estimate bridge fee invalid amount" do
    assert {:error, :invalid_amount} = CrossChainManager.estimate_bridge_fee(%{amount: 0, from_chain: :ethereum, to_chain: :polygon})
  end
end
