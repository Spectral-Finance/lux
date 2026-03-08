defmodule Lux.Prisms.Web3.Uniswap.PositionManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Uniswap.PositionManager

  setup do
    name = :"pm_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = PositionManager.start_link(name: name)
    %{pid: pid}
  end

  # --- Creation ---

  test "create position with valid params", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{
      token0: "WETH", token1: "USDC", fee_tier: 3000,
      price_lower: 1800.0, price_upper: 2200.0, amount0: 1.0, amount1: 2000.0
    })
    assert pos.pool.token0 == "WETH"
    assert pos.pool.token1 == "USDC"
    assert pos.pool.fee_tier == 3000
    assert pos.status == :active
    assert pos.amount0 == 1.0
    assert pos.amount1 == 2000.0
    assert is_binary(pos.id)
  end

  test "create position with default fee tier", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 1.0, price_upper: 2.0})
    assert pos.pool.fee_tier == 3000
  end

  test "reject invalid fee tier", %{pid: pid} do
    assert {:error, :invalid_fee_tier} =
      PositionManager.create_position(pid, %{token0: "A", token1: "B", fee_tier: 999})
  end

  test "reject missing tokens", %{pid: pid} do
    assert {:error, :missing_tokens} =
      PositionManager.create_position(pid, %{price_lower: 1.0, price_upper: 2.0})
  end

  test "reject same token pair", %{pid: pid} do
    assert {:error, :same_token} =
      PositionManager.create_position(pid, %{token0: "WETH", token1: "WETH"})
  end

  test "reject inverted price range", %{pid: pid} do
    assert {:error, :invalid_range} =
      PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 100.0, price_upper: 50.0})
  end

  test "reject negative price", %{pid: pid} do
    assert {:error, :negative_price} =
      PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: -1.0, price_upper: 2.0})
  end

  test "reject negative amount", %{pid: pid} do
    assert {:error, :negative_amount} =
      PositionManager.create_position(pid, %{token0: "A", token1: "B", amount0: -5})
  end

  test "all valid fee tiers accepted", %{pid: pid} do
    for tier <- [100, 500, 3000, 10_000] do
      {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", fee_tier: tier})
      assert pos.pool.fee_tier == tier
    end
  end

  # --- Close ---

  test "close position", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, closed} = PositionManager.close_position(pid, pos.id)
    assert closed.status == :closed
  end

  test "close already-closed position", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, _} = PositionManager.close_position(pid, pos.id)
    assert {:error, :already_closed} = PositionManager.close_position(pid, pos.id)
  end

  test "close nonexistent position", %{pid: pid} do
    assert {:error, :not_found} = PositionManager.close_position(pid, "nope")
  end

  # --- Get / List ---

  test "get position", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, found} = PositionManager.get_position(pid, pos.id)
    assert found.id == pos.id
  end

  test "get nonexistent", %{pid: pid} do
    assert {:error, :not_found} = PositionManager.get_position(pid, "nope")
  end

  test "list positions", %{pid: pid} do
    {:ok, _} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, _} = PositionManager.create_position(pid, %{token0: "C", token1: "D"})
    {:ok, list} = PositionManager.list_positions(pid)
    assert length(list) == 2
  end

  test "list empty", %{pid: pid} do
    {:ok, list} = PositionManager.list_positions(pid)
    assert list == []
  end

  # --- Fees ---

  test "collect fees", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, result} = PositionManager.collect_fees(pid, pos.id)
    assert result.collected.token0 == 0
    assert result.collected.token1 == 0
    assert result.position_id == pos.id
  end

  test "collect fees on closed position fails", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    PositionManager.close_position(pid, pos.id)
    assert {:error, :position_closed} = PositionManager.collect_fees(pid, pos.id)
  end

  test "collect fees nonexistent", %{pid: pid} do
    assert {:error, :not_found} = PositionManager.collect_fees(pid, "nope")
  end

  # --- Rebalance ---

  test "rebalance position", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 1.0, price_upper: 2.0})
    {:ok, updated} = PositionManager.rebalance(pid, pos.id, %{price_lower: 1.5, price_upper: 2.5})
    assert updated.price_lower == 1.5
    assert updated.price_upper == 2.5
  end

  test "rebalance with invalid range", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 1.0, price_upper: 2.0})
    assert {:error, :invalid_range} =
      PositionManager.rebalance(pid, pos.id, %{price_lower: 5.0, price_upper: 3.0})
  end

  test "rebalance closed position fails", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    PositionManager.close_position(pid, pos.id)
    assert {:error, :position_closed} = PositionManager.rebalance(pid, pos.id, %{price_lower: 1.0, price_upper: 2.0})
  end

  # --- Health Check ---

  test "health check in range", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 1800.0, price_upper: 2200.0})
    {:ok, health} = PositionManager.health_check(pid, pos.id)
    assert health.in_range
    refute health.needs_rebalance
    assert health.range_utilization == 50.0
  end

  test "health check returns IL estimate", %{pid: pid} do
    {:ok, pos} = PositionManager.create_position(pid, %{token0: "A", token1: "B", price_lower: 1000.0, price_upper: 3000.0})
    {:ok, health} = PositionManager.health_check(pid, pos.id)
    assert is_float(health.impermanent_loss_estimate)
  end

  # --- Portfolio ---

  test "portfolio summary", %{pid: pid} do
    {:ok, _} = PositionManager.create_position(pid, %{token0: "A", token1: "B"})
    {:ok, pos2} = PositionManager.create_position(pid, %{token0: "C", token1: "D"})
    PositionManager.close_position(pid, pos2.id)
    {:ok, summary} = PositionManager.portfolio_summary(pid)
    assert summary.total_positions == 2
    assert summary.active == 1
    assert summary.closed == 1
  end

  test "portfolio summary empty", %{pid: pid} do
    {:ok, summary} = PositionManager.portfolio_summary(pid)
    assert summary.total_positions == 0
    assert summary.active == 0
  end

  # --- Misc ---

  test "valid_fee_tiers/0 returns correct tiers" do
    assert PositionManager.valid_fee_tiers() == [100, 500, 3000, 10_000]
  end
end
