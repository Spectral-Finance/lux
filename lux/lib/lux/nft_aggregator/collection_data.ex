defmodule Lux.NFTAggregator.CollectionData do
  @moduledoc """
  Collection data aggregation for NFT marketplaces
  """
  
  defstruct [
    :name,
    :slug,
    :contract_address,
    :chain_id,
    :floor_price,
    :total_volume,
    :market_cap,
    :average_price,
    :owners,
    :items,
    :sales,
    :collections,
    :nft_data
  ]

  @doc """
  Initialize collection data structure
  """
end