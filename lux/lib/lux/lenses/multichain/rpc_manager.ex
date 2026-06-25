defmodule Lux.Lenses.MultiChain.RpcManager do
  @moduledoc """
  Multi-chain RPC endpoint management and configuration.

  Provides centralized management of RPC URLs, API keys, and connection
  settings for all supported EVM-compatible chains.

  ## Supported Chains

  | Chain | Chain ID | RPC URL |
  |-------|----------|---------|
  | Ethereum | 1 | https://api.etherscan.io/v2/api |
  | BNB Smart Chain | 56 | https://api.bscscan.com/api |
  | Polygon | 137 | https://api.polygonscan.com/api |
  | Arbitrum | 42161 | https://api.arbiscan.io/api |
  | Optimism | 10 | https://api-optimistic.etherscan.io/api |
  | Avalanche C-Chain | 43114 | https://api.snowtrace.io/api |
  | Fantom | 250 | https://api.ftmscan.com/api |
  | Base | 8453 | https://api.basescan.org/api |

  ## Examples

      iex> RpcManager.rpc_url(1)
      "https://eth.llamarpc.com"

      iex> RpcManager.supported_chains() |> length()
      8

      iex> RpcManager.supported?(56)
      true

      iex> RpcManager.supported?(99999)
      false
  """

  @typedoc "A single chain configuration"
  @type chain_config :: %{
          id: pos_integer(),
          name: String.t(),
          rpc_url: String.t(),
          api_url: String.t(),
          explorer_url: String.t(),
          native_currency: String.t(),
          block_time_seconds: non_neg_integer(),
          enabled: boolean()
        }

  @doc """
  Returns the list of all supported chain configurations.
  """
  @spec supported_chains() :: [chain_config()]
  def supported_chains do
    [
      %{
        id: 1,
        name: "Ethereum",
        rpc_url: "https://eth.llamarpc.com",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://etherscan.io",
        native_currency: "ETH",
        block_time_seconds: 12,
        enabled: true
      },
      %{
        id: 56,
        name: "BNB Smart Chain",
        rpc_url: "https://bsc-dataseed.binance.org",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://bscscan.com",
        native_currency: "BNB",
        block_time_seconds: 3,
        enabled: true
      },
      %{
        id: 137,
        name: "Polygon",
        rpc_url: "https://polygon-rpc.com",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://polygonscan.com",
        native_currency: "MATIC",
        block_time_seconds: 2,
        enabled: true
      },
      %{
        id: 42161,
        name: "Arbitrum",
        rpc_url: "https://arb1.arbitrum.io/rpc",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://arbiscan.io",
        native_currency: "ETH",
        block_time_seconds: 0.25,
        enabled: true
      },
      %{
        id: 10,
        name: "Optimism",
        rpc_url: "https://mainnet.optimism.io",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://optimistic.etherscan.io",
        native_currency: "ETH",
        block_time_seconds: 2,
        enabled: true
      },
      %{
        id: 43114,
        name: "Avalanche C-Chain",
        rpc_url: "https://api.avax.network/ext/bc/C/rpc",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://snowtrace.io",
        native_currency: "AVAX",
        block_time_seconds: 2,
        enabled: true
      },
      %{
        id: 250,
        name: "Fantom",
        rpc_url: "https://rpc.ftm.tools",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://ftmscan.com",
        native_currency: "FTM",
        block_time_seconds: 1,
        enabled: true
      },
      %{
        id: 8453,
        name: "Base",
        rpc_url: "https://mainnet.base.org",
        api_url: "https://api.etherscan.io/v2/api",
        explorer_url: "https://basescan.org",
        native_currency: "ETH",
        block_time_seconds: 2,
        enabled: true
      }
    ]
  end

  @doc """
  Returns the chain configuration for a given chain ID.
  """
  @spec get_chain(pos_integer()) :: chain_config() | nil
  def get_chain(chain_id) do
    supported_chains()
    |> Enum.find(%{enabled: false}, fn chain -> chain.id == chain_id end)
  end

  @doc """
  Returns the RPC URL for a given chain ID.
  """
  @spec rpc_url(pos_integer()) :: String.t()
  def rpc_url(chain_id) do
    case get_chain(chain_id) do
      %{enabled: false} -> raise ArgumentError, "Unsupported chain ID: #{chain_id}"
      chain -> chain.rpc_url
    end
  end

  @doc """
  Returns the API URL for a given chain ID.
  Uses Etherscan v2 multi-chain endpoint.
  """
  @spec api_url(pos_integer()) :: String.t()
  def api_url(chain_id) do
    case get_chain(chain_id) do
      %{enabled: false} -> raise ArgumentError, "Unsupported chain ID: #{chain_id}"
      _chain -> "https://api.etherscan.io/v2/api"
    end
  end

  @doc """
  Returns the block explorer URL for a given chain ID.
  """
  @spec explorer_url(pos_integer()) :: String.t()
  def explorer_url(chain_id) do
    case get_chain(chain_id) do
      %{enabled: false} -> raise ArgumentError, "Unsupported chain ID: #{chain_id}"
      chain -> chain.explorer_url
    end
  end

  @doc """
  Returns all enabled chain IDs.
  """
  @spec enabled_chain_ids() :: [pos_integer()]
  def enabled_chain_ids do
    supported_chains()
    |> Enum.filter(fn chain -> chain.enabled end)
    |> Enum.map(fn chain -> chain.id end)
  end

  @doc """
  Returns the number of supported (enabled) chains.
  """
  @spec chain_count() :: non_neg_integer()
  def chain_count do
    supported_chains()
    |> Enum.count(fn chain -> chain.enabled end)
  end

  @doc """
  Checks if a chain ID is supported.
  """
  @spec supported?(pos_integer()) :: boolean()
  def supported?(chain_id) do
    case get_chain(chain_id) do
      %{enabled: false} -> false
      _chain -> true
    end
  end

  @doc """
  Gets all chain configurations for the given chain IDs.
  Useful for batch operations.
  """
  @spec get_chains([pos_integer()]) :: [chain_config()]
  def get_chains(chain_ids) do
    chain_ids
    |> Enum.map(&get_chain/1)
    |> Enum.reject(fn chain -> chain.enabled == false end)
  end
end
