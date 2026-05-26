defmodule Lux.Integrations.PancakeSwap do
  @moduledoc """
  Common settings and functions for PancakeSwap integration.
  """

  @subgraphs %{
    "bsc" => "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-bsc",
    "ethereum" => "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-eth",
    "arbitrum" => "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-arb",
    "base" => "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-base"
  }

  @masterchef_subgraphs %{
    "bsc" => "https://api.thegraph.com/subgraphs/name/pancakeswap/masterchef-v3-bsc",
    "ethereum" => "https://api.thegraph.com/subgraphs/name/pancakeswap/masterchef-v3-eth"
  }

  def subgraph_url(chain), do: Map.get(@subgraphs, chain, @subgraphs["bsc"])
  def masterchef_subgraph_url(chain), do: Map.get(@masterchef_subgraphs, chain, @masterchef_subgraphs["bsc"])

  def headers, do: [{"Content-Type", "application/json"}]
end
