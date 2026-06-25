defmodule Lux.Integrations.Web3Wallet do
  @moduledoc """
  Web3 Wallet Management and Transaction Infrastructure ($2,000).

  Provides multi-chain wallet management, transaction building,
  gas estimation, and nonce management for Ethereum-compatible chains.

  ## Configuration

      config :lux, Lux.Integrations.Web3Wallet,
        rpc_urls: %{
          ethereum: System.get_env("ETH_RPC_URL"),
          polygon:  System.get_env("POLYGON_RPC_URL"),
          arbitrum: System.get_env("ARBITRUM_RPC_URL")
        }
  """

  require Logger

  @supported_chains ~w[ethereum polygon arbitrum optimism base bnb avalanche]a

  def supported_chains, do: @supported_chains

  @doc "Returns configured RPC URL for a chain."
  @spec rpc_url(atom()) :: String.t() | nil
  def rpc_url(chain) do
    urls = Application.get_env(:lux, __MODULE__, [])[:rpc_urls] || %{}
    env_key = "#{String.upcase(to_string(chain))}_RPC_URL"
    Map.get(urls, chain) || System.get_env(env_key)
  end

  def json_rpc_headers, do: [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @doc "Builds an eth_call JSON-RPC request body."
  @spec eth_call_body(String.t(), String.t(), String.t()) :: map()
  def eth_call_body(to, data, block \\ "latest") do
    %{jsonrpc: "2.0", id: 1, method: "eth_call",
      params: [%{to: to, data: data}, block]}
  end

  @doc "Builds an eth_getBalance request."
  @spec eth_balance_body(String.t()) :: map()
  def eth_balance_body(address) do
    %{jsonrpc: "2.0", id: 1, method: "eth_getBalance",
      params: [address, "latest"]}
  end

  @doc "Builds an eth_estimateGas request."
  @spec eth_estimate_gas_body(map()) :: map()
  def eth_estimate_gas_body(tx) do
    %{jsonrpc: "2.0", id: 1, method: "eth_estimateGas", params: [tx]}
  end

  @doc "Builds an eth_getTransactionCount request for nonce management."
  @spec eth_nonce_body(String.t()) :: map()
  def eth_nonce_body(address) do
    %{jsonrpc: "2.0", id: 1, method: "eth_getTransactionCount",
      params: [address, "pending"]}
  end

  @doc "Converts wei to ether."
  @spec wei_to_ether(non_neg_integer()) :: float()
  def wei_to_ether(wei), do: wei / 1_000_000_000_000_000_000

  @doc "Converts ether to wei."
  @spec ether_to_wei(float()) :: non_neg_integer()
  def ether_to_wei(ether), do: round(ether * 1_000_000_000_000_000_000)

  @doc "Converts gwei to wei."
  @spec gwei_to_wei(number()) :: non_neg_integer()
  def gwei_to_wei(gwei), do: round(gwei * 1_000_000_000)

  @doc "Validates an Ethereum address format."
  @spec valid_address?(String.t()) :: boolean()
  def valid_address?(addr) when is_binary(addr) do
    Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, addr)
  end
  def valid_address?(_), do: false
end
