defmodule Lux.Prisms.Sushiswap.CrossChainBridgePrism do
  @moduledoc """
  Prism for managing cross-chain bridges on SushiSwap.
  """

  import Lux.Services.Sushiswap, only: [get_bridge_details: 1, create_bridge: 1, update_bridge: 2, delete_bridge: 1]

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
end

def test_initiate_bridge_transfer() do
  bridge_params = %{
    source_chain: "Ethereum",
    destination_chain: "Polygon",
    token_address: "0x1234567890abcdef",
    amount: 100.0,
    recipient: "0x9876543210fedcba"
  }

  response = Lux.Prisms.Sushiswap.CrossChainBridgePrism.create_bridge(bridge_params)

  assert %{
    :source_chain => "Ethereum",
    :destination_chain => "Polygon",
    :token_address => "0x1234567890abcdef",
    :amount => 100.0,
    :recipient => "0x9876543210fedcba"
  } = response
end