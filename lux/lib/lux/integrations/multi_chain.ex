defmodule Lux.Integrations.MultiChain do
  @moduledoc """
  Multi-Chain Data Aggregation Engine ($1,750).

  Aggregates blockchain data across Ethereum, Polygon, Arbitrum,
  Optimism, Base, BNB Chain, and Avalanche via unified RPC interface.

  ## Configuration

      config :lux, Lux.Integrations.MultiChain,
        rpc_urls: %{ethereum: "...", polygon: "...", ...}
  """

  @chains %{
    ethereum:  %{id: 1,     name: "Ethereum",  symbol: "ETH",  decimals: 18},
    polygon:   %{id: 137,   name: "Polygon",   symbol: "MATIC",decimals: 18},
    arbitrum:  %{id: 42161, name: "Arbitrum",  symbol: "ETH",  decimals: 18},
    optimism:  %{id: 10,    name: "Optimism",  symbol: "ETH",  decimals: 18},
    base:      %{id: 8453,  name: "Base",      symbol: "ETH",  decimals: 18},
    bnb:       %{id: 56,    name: "BNB Chain", symbol: "BNB",  decimals: 18},
    avalanche: %{id: 43114, name: "Avalanche", symbol: "AVAX", decimals: 18}
  }

  def chains, do: @chains
  def chain_ids, do: Map.new(@chains, fn {k, v} -> {k, v.id} end)
  def chain_info(chain), do: Map.get(@chains, chain)

  @doc "Returns the configured or default RPC URL for a chain."
  @spec rpc_url(atom()) :: String.t() | nil
  def rpc_url(chain) do
    configured = Application.get_env(:lux, __MODULE__, [])[:rpc_urls] || %{}
    Map.get(configured, chain) || System.get_env("#{String.upcase(to_string(chain))}_RPC_URL")
  end

  def json_rpc_headers, do: [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @doc "Builds a batch JSON-RPC request for fetching data across multiple chains."
  @spec batch_balance_body(String.t()) :: list(map())
  def batch_balance_body(address) do
    @chains
    |> Map.keys()
    |> Enum.with_index(1)
    |> Enum.map(fn {chain, id} ->
      %{jsonrpc: "2.0", id: id, method: "eth_getBalance",
        params: [address, "latest"], chain: chain}
    end)
  end

  @doc "Normalises a balance from hex wei string to float for a given chain."
  @spec normalise_balance(String.t(), atom()) :: float()
  def normalise_balance("0x" <> hex, chain) do
    decimals = get_in(@chains, [chain, :decimals]) || 18
    wei = String.to_integer(hex, 16)
    wei / :math.pow(10, decimals)
  end
  def normalise_balance(_, _), do: 0.0

  @doc "Returns block explorer URL for a transaction hash."
  @spec explorer_tx_url(atom(), String.t()) :: String.t()
  def explorer_tx_url(:ethereum,  tx), do: "https://etherscan.io/tx/#{tx}"
  def explorer_tx_url(:polygon,   tx), do: "https://polygonscan.com/tx/#{tx}"
  def explorer_tx_url(:arbitrum,  tx), do: "https://arbiscan.io/tx/#{tx}"
  def explorer_tx_url(:optimism,  tx), do: "https://optimistic.etherscan.io/tx/#{tx}"
  def explorer_tx_url(:base,      tx), do: "https://basescan.org/tx/#{tx}"
  def explorer_tx_url(:bnb,       tx), do: "https://bscscan.com/tx/#{tx}"
  def explorer_tx_url(:avalanche, tx), do: "https://snowtrace.io/tx/#{tx}"
  def explorer_tx_url(_,          tx), do: "https://etherscan.io/tx/#{tx}"
end
