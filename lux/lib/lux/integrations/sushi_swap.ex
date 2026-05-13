defmodule Lux.Integrations.SushiSwap do
  @moduledoc """
  Common settings and chain helpers for SushiSwap integration.
  """

  @api_base_url "https://api.sushi.com"
  @default_referrer "lux"

  @chains %{
    ethereum: %{id: 1, name: "Ethereum", native_symbol: "ETH", confirmations: 12},
    optimism: %{id: 10, name: "Optimism", native_symbol: "ETH", confirmations: 20},
    bsc: %{id: 56, name: "BNB Smart Chain", native_symbol: "BNB", confirmations: 15},
    polygon: %{id: 137, name: "Polygon", native_symbol: "MATIC", confirmations: 128},
    arbitrum: %{id: 42_161, name: "Arbitrum", native_symbol: "ETH", confirmations: 20},
    avalanche: %{id: 43_114, name: "Avalanche", native_symbol: "AVAX", confirmations: 20},
    base: %{id: 8453, name: "Base", native_symbol: "ETH", confirmations: 20},
    linea: %{id: 59_144, name: "Linea", native_symbol: "ETH", confirmations: 20}
  }

  @bridge_providers [:sushixswap, :lifi, :stargate, :cctp, :route_processor]

  @doc "Returns default Sushi API settings."
  @spec client_settings() :: map()
  def client_settings do
    %{
      base_url: @api_base_url,
      referrer: @default_referrer,
      headers: [{"accept", "application/json"}]
    }
  end

  @doc "Returns supported SushiSwap chains."
  @spec supported_chains() :: map()
  def supported_chains, do: @chains

  @doc "Returns supported bridge providers."
  @spec bridge_providers() :: [atom()]
  def bridge_providers, do: @bridge_providers

  @doc "Returns a chain id from an atom, string, or integer chain identifier."
  @spec chain_id(atom() | String.t() | integer()) :: integer() | nil
  def chain_id(chain) when is_integer(chain), do: chain
  def chain_id(chain) when is_atom(chain), do: get_in(@chains, [chain, :id])

  def chain_id(chain) when is_binary(chain) do
    case chain_key(chain) do
      nil -> parse_integer(chain)
      key -> chain_id(key)
    end
  end

  @doc "Returns a known chain key without creating atoms from user input."
  @spec chain_key(atom() | String.t() | integer()) :: atom() | nil
  def chain_key(chain) when is_atom(chain) do
    if Map.has_key?(@chains, chain), do: chain
  end

  def chain_key(chain) when is_integer(chain) do
    @chains
    |> Enum.find_value(fn {key, info} ->
      if info.id == chain, do: key
    end)
  end

  def chain_key(chain) when is_binary(chain) do
    normalized =
      chain
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")

    Enum.find_value(@chains, fn {key, info} ->
      key_name = Atom.to_string(key)
      display_name = info.name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_")

      if normalized in [key_name, display_name, Integer.to_string(info.id)], do: key
    end)
  end

  @doc "Builds a deterministic bridge pair descriptor for cross-chain workflows."
  @spec bridge_pair(atom() | String.t() | integer(), atom() | String.t() | integer()) ::
          {:ok, map()} | {:error, term()}
  def bridge_pair(from_chain, to_chain) do
    with from when not is_nil(from) <- chain_key(from_chain),
         to when not is_nil(to) <- chain_key(to_chain),
         false <- from == to do
      {:ok,
       %{
         from_chain: from,
         to_chain: to,
         from_chain_id: chain_id(from),
         to_chain_id: chain_id(to),
         providers: @bridge_providers,
         required_confirmations: max(@chains[from].confirmations, @chains[to].confirmations)
       }}
    else
      true -> {:error, :same_chain}
      _ -> {:error, :unsupported_chain}
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end
end
