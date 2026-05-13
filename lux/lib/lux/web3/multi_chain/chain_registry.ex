defmodule Lux.Web3.MultiChain.ChainRegistry do
  @moduledoc """
  Registry for EVM-compatible chains used by multi-chain aggregation.
  """

  @chains %{
    ethereum: %{chain_id: 1, name: "Ethereum", native_symbol: "ETH", block_time_ms: 12_000},
    polygon: %{chain_id: 137, name: "Polygon", native_symbol: "MATIC", block_time_ms: 2_000},
    bsc: %{chain_id: 56, name: "BNB Smart Chain", native_symbol: "BNB", block_time_ms: 3_000},
    arbitrum: %{chain_id: 42_161, name: "Arbitrum One", native_symbol: "ETH", block_time_ms: 250},
    optimism: %{chain_id: 10, name: "OP Mainnet", native_symbol: "ETH", block_time_ms: 2_000},
    base: %{chain_id: 8_453, name: "Base", native_symbol: "ETH", block_time_ms: 2_000}
  }

  @doc """
  Lists built-in chain definitions.
  """
  @spec all() :: map()
  def all, do: @chains

  @doc """
  Fetches a chain definition by atom, string key, or integer chain id.
  """
  @spec fetch(atom() | String.t() | integer()) :: {:ok, map()} | {:error, :unknown_chain}
  def fetch(chain) when is_atom(chain), do: fetch_by_key(chain)

  def fetch(chain) when is_binary(chain) do
    case Integer.parse(chain) do
      {chain_id, ""} -> fetch(chain_id)
      _ -> chain |> String.downcase() |> String.to_existing_atom() |> fetch_by_key()
    rescue
      ArgumentError -> {:error, :unknown_chain}
    end
  end

  def fetch(chain_id) when is_integer(chain_id) do
    @chains
    |> Enum.find(fn {_key, chain} -> chain.chain_id == chain_id end)
    |> case do
      {key, chain} -> {:ok, Map.put(chain, :key, key)}
      nil -> {:error, :unknown_chain}
    end
  end

  @doc """
  Fetches a configured RPC URL for the chain.
  """
  @spec rpc_url(atom() | String.t() | integer(), keyword() | map()) ::
          {:ok, String.t()} | {:error, term()}
  def rpc_url(chain, opts \\ %{}) do
    with {:ok, chain_info} <- fetch(chain) do
      rpc_urls = opts[:rpc_urls] || Application.get_env(:lux, __MODULE__, [])[:rpc_urls] || %{}

      case rpc_urls[chain_info.key] || rpc_urls[to_string(chain_info.key)] do
        nil -> {:error, {:missing_rpc_url, chain_info.key}}
        url -> {:ok, url}
      end
    end
  end

  defp fetch_by_key(key) do
    case Map.fetch(@chains, key) do
      {:ok, chain} -> {:ok, Map.put(chain, :key, key)}
      :error -> {:error, :unknown_chain}
    end
  end
end
