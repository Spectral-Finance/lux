defmodule Lux.Prisms.Sushiswap.PoolManagementPrism do
  @moduledoc """
  Prism for managing SushiSwap pools.
  """

  import Lux.Services.Sushiswap, only: [get_pool_details: 1, create_pool: 1, update_pool: 2, delete_pool: 1]

  def get_pool_details(pool_id) do
    Sushiswap.get_pool_details(pool_id)
  end

  def create_pool(params) do
    Sushiswap.create_pool(params)
  end

  def update_pool(pool_id, params) do
    Sushiswap.update_pool(pool_id, params)
  end

  def delete_pool(pool_id) do
    Sushiswap.delete_pool(pool_id)
  end

  def initialize_pools() do
    pools = Sushiswap.list_all_pools()
    Enum.each(pools, fn pool -> Lux.Prisms.Sushiswap.PoolManagementPrism.update_pool(pool.id, pool.params) end)
  end
end

def fetch_pool_data(pool_id) do
  Lux.Prisms.Sushiswap.PoolManagementPrism.get_pool_details(pool_id)
end