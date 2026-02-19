defmodule Lux.Chain do
  @moduledoc """
  Unified chain configuration and registry for EVM-compatible networks.

  Provides a standardized way to reference and configure blockchain networks
  used throughout the multi-chain data aggregation engine.

  ## Supported Chains

  - Ethereum Mainnet (chain_id: 1)
  - Polygon (chain_id: 137)
  - BSC / BNB Chain (chain_id: 56)
  - Arbitrum One (chain_id: 42161)
  - Optimism (chain_id: 10)
  - Base (chain_id: 8453)
  - Avalanche C-Chain (chain_id: 43114)

  ## Usage

      iex> Lux.Chain.get(:ethereum)
      %Lux.Chain{
        id: :ethereum,
        chain_id: 1,
        name: "Ethereum Mainnet",
        native_currency: "ETH",
        ...
      }

      iex> Lux.Chain.from_chain_id(137)
      {:ok, %Lux.Chain{id: :polygon, ...}}
  """

  @type t :: %__MODULE__{
          id: atom(),
          chain_id: pos_integer(),
          name: String.t(),
          native_currency: String.t(),
          currency_decimals: pos_integer(),
          block_time_ms: pos_integer(),
          explorer_url: String.t() | nil,
          rpc_url: String.t() | nil
        }

  defstruct [
    :id,
    :chain_id,
    :name,
    :native_currency,
    :rpc_url,
    currency_decimals: 18,
    block_time_ms: 12_000,
    explorer_url: nil
  ]

  # Chain definitions stored as maps, converted to structs at runtime
  @chain_defs %{
    ethereum: %{
      id: :ethereum,
      chain_id: 1,
      name: "Ethereum Mainnet",
      native_currency: "ETH",
      currency_decimals: 18,
      block_time_ms: 12_000,
      explorer_url: "https://etherscan.io"
    },
    polygon: %{
      id: :polygon,
      chain_id: 137,
      name: "Polygon",
      native_currency: "MATIC",
      currency_decimals: 18,
      block_time_ms: 2_000,
      explorer_url: "https://polygonscan.com"
    },
    bsc: %{
      id: :bsc,
      chain_id: 56,
      name: "BNB Smart Chain",
      native_currency: "BNB",
      currency_decimals: 18,
      block_time_ms: 3_000,
      explorer_url: "https://bscscan.com"
    },
    arbitrum: %{
      id: :arbitrum,
      chain_id: 42_161,
      name: "Arbitrum One",
      native_currency: "ETH",
      currency_decimals: 18,
      block_time_ms: 250,
      explorer_url: "https://arbiscan.io"
    },
    optimism: %{
      id: :optimism,
      chain_id: 10,
      name: "Optimism",
      native_currency: "ETH",
      currency_decimals: 18,
      block_time_ms: 2_000,
      explorer_url: "https://optimistic.etherscan.io"
    },
    base: %{
      id: :base,
      chain_id: 8453,
      name: "Base",
      native_currency: "ETH",
      currency_decimals: 18,
      block_time_ms: 2_000,
      explorer_url: "https://basescan.org"
    },
    avalanche: %{
      id: :avalanche,
      chain_id: 43_114,
      name: "Avalanche C-Chain",
      native_currency: "AVAX",
      currency_decimals: 18,
      block_time_ms: 2_000,
      explorer_url: "https://snowtrace.io"
    }
  }

  @chain_id_map @chain_defs
               |> Enum.map(fn {_k, v} -> {v.chain_id, v.id} end)
               |> Map.new()

  @doc """
  Returns the chain configuration for the given chain identifier.

  ## Examples

      iex> Lux.Chain.get(:ethereum)
      %Lux.Chain{id: :ethereum, chain_id: 1, name: "Ethereum Mainnet", ...}

      iex> Lux.Chain.get(:unknown)
      nil
  """
  @spec get(atom()) :: t() | nil
  def get(chain_id) when is_atom(chain_id) do
    case Map.get(@chain_defs, chain_id) do
      nil -> nil
      def_map -> struct(__MODULE__, def_map)
    end
  end

  @doc """
  Returns the chain configuration for the given chain identifier, raising if not found.
  """
  @spec get!(atom()) :: t()
  def get!(chain_id) when is_atom(chain_id) do
    case get(chain_id) do
      nil -> raise ArgumentError, "Unknown chain: #{inspect(chain_id)}"
      chain -> chain
    end
  end

  @doc """
  Looks up a chain by its numeric chain ID.

  ## Examples

      iex> Lux.Chain.from_chain_id(1)
      {:ok, %Lux.Chain{id: :ethereum, ...}}

      iex> Lux.Chain.from_chain_id(999999)
      {:error, :unknown_chain}
  """
  @spec from_chain_id(pos_integer()) :: {:ok, t()} | {:error, :unknown_chain}
  def from_chain_id(numeric_id) when is_integer(numeric_id) do
    case Map.get(@chain_id_map, numeric_id) do
      nil -> {:error, :unknown_chain}
      chain_atom -> {:ok, get(chain_atom)}
    end
  end

  @doc """
  Returns all supported chains as a list.
  """
  @spec all() :: [t()]
  def all do
    Enum.map(@chain_defs, fn {_k, def_map} -> struct(__MODULE__, def_map) end)
  end

  @doc """
  Returns all supported chain identifiers.
  """
  @spec supported_ids() :: [atom()]
  def supported_ids, do: Map.keys(@chain_defs)

  @doc """
  Checks if a chain identifier is supported.
  """
  @spec supported?(atom()) :: boolean()
  def supported?(chain_id) when is_atom(chain_id) do
    Map.has_key?(@chain_defs, chain_id)
  end

  @doc """
  Returns the Etherscan-compatible chain ID for API requests.
  """
  @spec etherscan_chain_id(atom()) :: pos_integer() | nil
  def etherscan_chain_id(chain_id) when is_atom(chain_id) do
    case get(chain_id) do
      nil -> nil
      chain -> chain.chain_id
    end
  end
end
