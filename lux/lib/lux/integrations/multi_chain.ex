defmodule Lux.Integrations.MultiChain do
  @moduledoc """
  Integration for multi-chain data aggregation.
  Handles RPC configurations for multiple EVM-compatible networks.
  """

  @doc """
  Gets the RPC URL for a specific chain.
  """
  def rpc_url(chain) do
    api_key = Lux.Config.alchemy_api_key() || ""
    
    networks = %{
      "ethereum" => if(api_key != "", do: "https://eth-mainnet.g.alchemy.com/v2/#{api_key}", else: "https://cloudflare-eth.com"),
      "polygon" => if(api_key != "", do: "https://polygon-mainnet.g.alchemy.com/v2/#{api_key}", else: "https://polygon-rpc.com"),
      "bsc" => "https://bsc-dataseed.binance.org/",
      "avalanche" => "https://api.avax.network/ext/bc/C/rpc",
      "arbitrum" => if(api_key != "", do: "https://arb-mainnet.g.alchemy.com/v2/#{api_key}", else: "https://arb1.arbitrum.io/rpc")
    }

    Map.get(networks, String.downcase(chain), networks["ethereum"])
  end
end
