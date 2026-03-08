defmodule Lux.Integrations.Web3.Gas.TransactionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Gas.TransactionManager

  setup do
    {:ok, pid} = TransactionManager.start_link(name: nil)
    %{pid: pid}
  end

  test "submit transaction", %{pid: pid} do
    assert {:ok, result} = TransactionManager.submit(pid, %{to: "0xabc", value: 100, gas_price: 30})
    assert result.status == :pending
    assert is_binary(result.id)
  end

  test "speed up transaction", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc", gas_price: 30})
    assert {:ok, result} = TransactionManager.speed_up(pid, id, 2.0)
    assert result.new_gas_price == 60
    assert result.speed_ups == 1
  end

  test "cancel transaction", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc"})
    assert {:ok, %{status: :cancelled}} = TransactionManager.cancel(pid, id)
  end

  test "status of transaction", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc"})
    assert {:ok, entry} = TransactionManager.status(pid, id)
    assert entry.status == :pending
  end

  test "list transactions", %{pid: pid} do
    TransactionManager.submit(pid, %{to: "0xa"})
    TransactionManager.submit(pid, %{to: "0xb"})
    assert length(TransactionManager.list(pid)) == 2
  end

  test "batch transactions", %{pid: pid} do
    assert {:ok, result} = TransactionManager.batch(pid, [
      %{to: "0xa", value: 1}, %{to: "0xb", value: 2}, %{to: "0xc", value: 3}
    ])
    assert result.count == 3
    assert length(result.batch_ids) == 3
  end

  test "speed_up unknown returns error", %{pid: pid} do
    assert {:error, :not_found} = TransactionManager.speed_up(pid, "nonexistent")
  end

  test "cancel unknown returns error", %{pid: pid} do
    assert {:error, :not_found} = TransactionManager.cancel(pid, "nonexistent")
  end
end
