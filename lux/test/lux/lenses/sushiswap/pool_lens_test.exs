defmodule Lux.Lenses.Sushiswap.PoolLensTest do
  use ExUnit.Case
  alias Lux.Prisms.Sushiswap.PoolManagementPrism

  test "get_pool_details/1 returns pool details" do
    pool_id = "test_pool_id"
    expected_details = %{pool_id: pool_id, liquidity: 1000}
    allow(Sushiswap, :get_pool_details, return: expected_details)
    assert PoolManagementPrism.get_pool_details(pool_id) == expected_details
  end

  test "create_pool/1 creates a new pool" do
    params = %{pool_id: "new_pool", liquidity: 500}
    allow(Sushiswap, :create_pool, return: {:ok, params})
    assert PoolManagementPrism.create_pool(params) == {:ok, params}
  end

  test "update_pool/2 updates an existing pool" do
    pool_id = "existing_pool"
    params = %{liquidity: 1500}
    allow(Sushiswap, :update_pool, return: {:ok, params})
    assert PoolManagementPrism.update_pool(pool_id, params) == {:ok, params}
  end

  test "delete_pool/1 deletes a pool" do
    pool_id = "pool_to_delete"
    allow(Sushiswap, :delete_pool, return: :ok)
    assert PoolManagementPrism.delete_pool(pool_id) == :ok
  end
end

test "fetch_pool_details/1 fetches pool details" do
  pool_id = "test_pool_id"
  expected_details = %{pool_id: pool_id, liquidity: 1000}
  allow(Sushiswap, :get_pool_details, return: expected_details)
  assert PoolManagementPrism.fetch_pool_details(pool_id) == expected_details
end