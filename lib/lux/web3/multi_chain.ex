
defmodule Lux.Web3.MultiChain do
  @moduledoc """
  Multi-chain data aggregation engine supporting Ethereum, Polygon, Arbitrum, Optimism, and Base.

  Provides balance queries, multi-chain aggregation, and ERC-20 token balance lookups
  across supported EVM-compatible chains via JSON-RPC.
  """

  @chains %{
    ethereum: %{name: "Ethereum", rpc: "https://eth.llamarpc.com", native: "ETH", decimals: 18, explorer: "https://etherscan.io"},
    polygon: %{name: "Polygon", rpc: "https://polygon.llamarpc.com", native: "MATIC", decimals: 18, explorer: "https://polygonscan.com"},
    arbitrum: %{name: "Arbitrum", rpc: "https://arbitrum.llamarpc.com", native: "ETH", decimals: 18, explorer: "https://arbiscan.io"},
    optimism: %{name: "Optimism", rpc: "https://optimism.llamarpc.com", native: "ETH", decimals: 18, explorer: "https://optimistic.etherscan.io"},
    base: %{name: "Base", rpc: "https://base.llamarpc.com", native: "ETH", decimals: 18, explorer: "https://basescan.org"}
  }

  @doc "Returns the full chains map."
  def chains, do: @chains

  @doc "Returns chain info for a given key, or nil if unsupported."
  def chain_info(key), do: Map.get(@chains, key)

  @doc """
  Queries the native balance of an address on a single chain.

  Returns `{:ok, %{wei: int, eth: float}}` on success, or `{:error, term}`.
  """
  def balance(address, chain \\ :ethereum) do
    with {:ok, info} <- resolve_chain(chain),
         {:ok, hex} <- rpc_call(info.rpc, "eth_getBalance", [address, "latest"]) do
      wei = hex_to_int(hex)
      {:ok, %{chain: chain, address: address, wei: wei, eth: wei / 1_000_000_000_000_000_000}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Queries native balance across ALL supported chains.

  Returns `{:ok, %{chain_name => result}}` where result is
  `%{wei: int, eth: float}` or `%{error: reason}` for failed chains.
  """
  def multi_chain_balance(address) do
    results =
      Enum.reduce(@chains, %{}, fn {key, %{rpc: rpc}}, acc ->
        case rpc_call(rpc, "eth_getBalance", [address, "latest"]) do
          {:ok, hex} ->
            wei = hex_to_int(hex)
            Map.put(acc, key, %{wei: wei, eth: wei / 1_000_000_000_000_000_000})
          {:error, reason} ->
            Map.put(acc, key, %{error: inspect(reason)})
        end
      end)
    {:ok, results}
  end

  @doc """
  Queries the ERC-20 token balance of an address for a given contract on a single chain.

  Returns `{:ok, %{chain: atom, contract: binary, address: binary, wei: int}}` on success,
  or `{:error, term}`.
  """
  def token_balance(contract, address, chain \\ :ethereum) do
    with {:ok, info} <- resolve_chain(chain) do
      # ERC-20 balanceOf selector (0x70a08231) + left-padded address (32 bytes = 64 hex chars)
      address_data = address |> String.replace_prefix("0x", "") |> String.downcase() |> String.pad_leading(64, "0")
      data = "0x70a08231" <> address_data

      case rpc_call(info.rpc, "eth_call", [%{to: contract, data: data}, "latest"]) do
        {:ok, hex} -> {:ok, %{chain: chain, contract: contract, address: address, wei: hex_to_int(hex)}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Private helpers ──────────────────────────────────────

  @doc false
  def resolve_chain(key) do
    case Map.get(@chains, key) do
      nil -> {:error, {:unsupported_chain, key}}
      info -> {:ok, info}
    end
  end

  @doc false
  def hex_to_int(hex) when is_binary(hex) do
    String.to_integer(String.replace_prefix(hex, "0x", ""), 16)
  end

  @doc false
  defp rpc_call(url, method, params) do
    case Req.post(url,
           json: %{jsonrpc: "2.0", id: 1, method: method, params: params},
           headers: [{"Content-Type", "application/json"}],
           receive_timeout: 10_000
         ) do
      {:ok, %{status: 200, body: %{"result" => r}}} -> {:ok, r}
      {:ok, %{status: 200, body: %{"error" => e}}} -> {:error, e}
      {:error, err} -> {:error, err}
    end
  end
end
