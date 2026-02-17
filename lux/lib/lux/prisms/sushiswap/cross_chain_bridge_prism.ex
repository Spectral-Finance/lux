defmodule Lux.Prisms.Sushiswap.CrossChainBridgePrism do
  @moduledoc """
  Prism for handling cross-chain bridge operations.
  """

  import Lux.Services.Sushiswap, only: [get_bridge_details: 1, create_bridge: 1, update_bridge: 2, delete_bridge: 1]
  import Lux.Services.PoolManagement, only: [manage_pool: 2]

  def get_bridge_details(bridge_id) do
    Sushiswap.get_bridge_details(bridge_id)
  end

  def create_bridge(params) do
    Sushiswap.create_bridge(params)
  end

  def update_bridge(bridge_id, params) do
    Sushiswap.update_bridge(bridge_id, params)
  end

  def delete_bridge(bridge_id) do
    Sushiswap.delete_bridge(bridge_id)
  end

  def manage_pool(pool_id, action) do
    PoolManagement.manage_pool(pool_id, action)
  end
end

def optimize_gas_usage(bridge_id, params) do
  Sushiswap.optimize_gas_usage(bridge_id, params)
end