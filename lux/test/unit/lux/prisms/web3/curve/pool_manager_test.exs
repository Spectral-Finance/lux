defmodule Lux.Prisms.Web3.Curve.PoolManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Curve.PoolManager

  setup do
    name = :"curve_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = PoolManager.start_link(name: name)
    %{pid: pid}
  end

  # --- Add Liquidity ---

  test "add liquidity with full params", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", tokens: ["DAI", "USDC", "USDT"], amounts: [1000, 1000, 1000], lp_amount: 3000.0})
    assert pos.pool == "3pool"
    assert pos.status == :active
    assert pos.lp_tokens == 3000.0
    assert length(pos.tokens) == 3
    refute pos.staked
  end

  test "add liquidity missing pool", %{pid: pid} do
    assert {:error, :missing_pool} = PoolManager.add_liquidity(pid, %{lp_amount: 100})
  end

  test "add liquidity negative amount", %{pid: pid} do
    assert {:error, :negative_amount} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: -100})
  end

  # --- Remove Liquidity ---

  test "remove liquidity partial", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 1000.0})
    {:ok, result} = PoolManager.remove_liquidity(pid, pos.id, 50)
    assert result.removed_lp == 500.0
    assert result.remaining_lp == 500.0
    assert result.position.status == :active
  end

  test "remove liquidity full closes position", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 1000.0})
    {:ok, result} = PoolManager.remove_liquidity(pid, pos.id, 100)
    assert result.position.status == :closed
    assert result.remaining_lp == 0.0
  end

  test "remove liquidity invalid percentage", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    assert {:error, :invalid_percentage} = PoolManager.remove_liquidity(pid, pos.id, 0)
    assert {:error, :invalid_percentage} = PoolManager.remove_liquidity(pid, pos.id, 101)
  end

  test "remove liquidity from closed position", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    PoolManager.remove_liquidity(pid, pos.id, 100)
    assert {:error, :position_closed} = PoolManager.remove_liquidity(pid, pos.id, 50)
  end

  test "remove liquidity not found", %{pid: pid} do
    assert {:error, :not_found} = PoolManager.remove_liquidity(pid, "nope", 50)
  end

  # --- Gauge Staking ---

  test "stake gauge", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    {:ok, staked} = PoolManager.stake_gauge(pid, pos.id)
    assert staked.staked
  end

  test "stake already staked", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    {:ok, _} = PoolManager.stake_gauge(pid, pos.id)
    assert {:error, :already_staked} = PoolManager.stake_gauge(pid, pos.id)
  end

  test "stake closed position", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    PoolManager.remove_liquidity(pid, pos.id, 100)
    assert {:error, :position_closed} = PoolManager.stake_gauge(pid, pos.id)
  end

  test "unstake gauge", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    {:ok, _} = PoolManager.stake_gauge(pid, pos.id)
    {:ok, unstaked} = PoolManager.unstake_gauge(pid, pos.id)
    refute unstaked.staked
  end

  test "unstake when not staked", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    assert {:error, :not_staked} = PoolManager.unstake_gauge(pid, pos.id)
  end

  # --- Rewards ---

  test "claim rewards", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    {:ok, result} = PoolManager.claim_rewards(pid, pos.id)
    assert result.claimed.crv == 0
    assert result.claimed.extra == []
  end

  test "claim rewards not found", %{pid: pid} do
    assert {:error, :not_found} = PoolManager.claim_rewards(pid, "nope")
  end

  # --- Get / List ---

  test "get and list positions", %{pid: pid} do
    {:ok, pos} = PoolManager.add_liquidity(pid, %{pool: "3pool", lp_amount: 100.0})
    {:ok, found} = PoolManager.get_position(pid, pos.id)
    assert found.id == pos.id
    {:ok, list} = PoolManager.list_positions(pid)
    assert length(list) == 1
  end

  test "not found", %{pid: pid} do
    assert {:error, :not_found} = PoolManager.get_position(pid, "nope")
  end

  test "list empty", %{pid: pid} do
    {:ok, list} = PoolManager.list_positions(pid)
    assert list == []
  end

  # --- Pool Analysis ---

  test "analyze high tvl pool", _ctx do
    {:ok, analysis} = PoolManager.analyze_pool(%{tvl: 500_000_000, volume_24h: 50_000_000, fee_rate: 0.0004})
    assert analysis.apr_estimate > 0
    assert analysis.risk_score <= 20
    assert analysis.daily_fees > 0
    assert analysis.utilization > 0
  end

  test "analyze low tvl pool", _ctx do
    {:ok, analysis} = PoolManager.analyze_pool(%{tvl: 500_000, volume_24h: 10_000})
    assert analysis.risk_score >= 50
  end

  test "analyze zero tvl", _ctx do
    {:ok, analysis} = PoolManager.analyze_pool(%{tvl: 0})
    assert analysis.apr_estimate == 0.0
  end

  test "analyze pool recommendations", _ctx do
    {:ok, high} = PoolManager.analyze_pool(%{tvl: 100_000, volume_24h: 100_000, fee_rate: 0.01})
    assert high.recommendation in [:very_attractive, :attractive]

    {:ok, low} = PoolManager.analyze_pool(%{tvl: 1_000_000_000, volume_24h: 1000})
    assert low.recommendation == :low_yield
  end

  test "analyze multi-token pool risk", _ctx do
    {:ok, two} = PoolManager.analyze_pool(%{tvl: 50_000_000, num_tokens: 2})
    {:ok, four} = PoolManager.analyze_pool(%{tvl: 50_000_000, num_tokens: 4})
    assert four.risk_score > two.risk_score
  end
end
