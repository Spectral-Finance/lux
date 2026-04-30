defmodule Lux.Integrations.EtherscanMonitor do
  @moduledoc """
  Integration module for Etherscan API monitoring across multiple blockchain networks.

  Provides common configuration, authentication, and utilities for the Etherscan
  event monitoring lenses including contract events, token transfers, internal
  transactions, new contract deployments, and Uniswap V3 swaps.

  ## Supported Chains

  The module supports the following blockchain networks through chain IDs:

  | Chain        | Chain ID | Base URL                                    |
  |--------------|----------|---------------------------------------------|
  | Ethereum     | 1        | https://api.etherscan.io/v2/api             |
  | Polygon      | 137      | https://api.polygonscan.com/v2/api          |
  | BSC          | 56       | https://api.bscscan.com/v2/api              |
  | Arbitrum     | 42161    | https://api.arbiscan.io/v2/api              |
  | Optimism     | 10       | https://api-optimistic.etherscan.io/v2/api  |

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.EtherscanMonitor,
        api_key: System.get_env("ETHERSCAN_API_KEY"),
        default_chain: System.get_env("ETHERSCAN_DEFAULT_CHAIN") || "ethereum"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      ETHERSCAN_API_KEY="your-api-key-here"
      ETHERSCAN_DEFAULT_CHAIN="ethereum"  # Optional, defaults to "ethereum"

  ## Authentication

  Authentication is handled via API key passed as a query parameter.
  The key is fetched from the application configuration and added
  automatically to all lens requests.

  ## Usage Examples

  ### Basic Setup

      alias Lux.Integrations.EtherscanMonitor

      # Get configured base URL for Ethereum
      url = EtherscanMonitor.base_url()
      # => "https://api.etherscan.io/v2/api"

      # Get base URL for a specific chain
      url = EtherscanMonitor.base_url(:polygon)
      # => "https://api.polygonscan.com/v2/api"

      # Get authentication headers
      headers = EtherscanMonitor.headers()
      # => [{"content-type", "application/json"}]

      # Get auth config
      auth = EtherscanMonitor.auth()
      # => %{type: :custom, auth_function: &__MODULE__.add_api_key/1}

  ### Using with Lenses

      defmodule MyApp.Lenses.MyEventLens do
        use Lux.Lens,
          name: "My Event Lens",
          url: "#{EtherscanMonitor.base_url()}/api",
          method: :get,
          headers: EtherscanMonitor.headers(),
          auth: EtherscanMonitor.auth(),
          schema: %{
            type: :object,
            properties: %{
              chainid: %{type: :integer, default: 1}
            }
          }
      end

  ### Multi-Chain Monitoring

      # Monitor events on Ethereum
      Lux.Lenses.Etherscan.Events.ContractEventLens.focus(%{
        contract_address: "0x...",
        topic0: "0x...",
        from_block: 18_000_000,
        to_block: 18_001_000,
        chainid: 1
      })

      # Monitor events on Polygon
      Lux.Lenses.Etherscan.Events.ContractEventLens.focus(%{
        contract_address: "0x...",
        topic0: "0x...",
        from_block: 45_000_000,
        to_block: 45_001_000,
        chainid: 137
      })
  """

  @type chain :: :ethereum | :polygon | :bsc | :arbitrum | :optimism
  @type chain_id :: non_neg_integer()
  @type api_key :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type auth_config :: map()

  require Logger

  @chain_urls %{
    ethereum: "https://api.etherscan.io/v2/api",
    polygon: "https://api.polygonscan.com/v2/api",
    bsc: "https://api.bscscan.com/v2/api",
    arbitrum: "https://api.arbiscan.io/v2/api",
    optimism: "https://api-optimistic.etherscan.io/v2/api"
  }

  @chain_ids %{
    ethereum: 1,
    polygon: 137,
    bsc: 56,
    arbitrum: 42161,
    optimism: 10
  }

  @doc """
  Returns the Etherscan API base URL for the configured chain.

  Defaults to Ethereum mainnet if no chain is specified.

  ## Parameters

    - `chain` - Optional chain atom (:ethereum, :polygon, :bsc, :arbitrum, :optimism)

  ## Examples

      iex> EtherscanMonitor.base_url()
      "https://api.etherscan.io/v2/api"

      iex> EtherscanMonitor.base_url(:polygon)
      "https://api.polygonscan.com/v2/api"
  """
  @spec base_url(chain()) :: String.t()
  def base_url(chain \\ :ethereum) do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:default_chain, chain)
    |> case do
      chain when is_atom(chain) ->
        Map.get(@chain_urls, chain, Map.get(@chain_urls, :ethereum))

      _ ->
        Map.get(@chain_urls, :ethereum)
    end
  end

  @doc """
  Returns the chain ID for the given chain name.

  ## Parameters

    - `chain` - Chain atom (:ethereum, :polygon, :bsc, :arbitrum, :optimism)

  ## Examples

      iex> EtherscanMonitor.chain_id(:ethereum)
      1

      iex> EtherscanMonitor.chain_id(:polygon)
      137
  """
  @spec chain_id(chain()) :: chain_id()
  def chain_id(chain) do
    Map.get(@chain_ids, chain, 1)
  end

  @doc """
  Returns the chain name for the given chain ID.

  ## Parameters

    - `id` - Chain ID integer

  ## Examples

      iex> EtherscanMonitor.chain_name(1)
      :ethereum

      iex> EtherscanMonitor.chain_name(137)
      :polygon
  """
  @spec chain_name(chain_id()) :: chain()
  def chain_name(id) do
    @chain_ids
    |> Enum.find(fn {_name, chain_id} -> chain_id == id end)
    |> case do
      {name, _id} -> name
      nil -> :ethereum
    end
  end

  @doc """
  Returns the list of supported chains.

  ## Examples

      iex> EtherscanMonitor.supported_chains()
      [:ethereum, :polygon, :bsc, :arbitrum, :optimism]
  """
  @spec supported_chains() :: [chain()]
  def supported_chains do
    Map.keys(@chain_urls)
  end

  @doc """
  Returns common headers for Etherscan API requests.

  ## Examples

      iex> EtherscanMonitor.headers()
      [{"content-type", "application/json"}]
  """
  @spec headers() :: headers()
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Returns the authentication configuration for Etherscan API requests.

  Uses a custom auth function that adds the API key as a query parameter.

  ## Examples

      iex> EtherscanMonitor.auth()
      %{type: :custom, auth_function: &EtherscanMonitor.add_api_key/1}
  """
  @spec auth() :: auth_config()
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    }
  end

  @doc """
  Adds the API key to the lens parameters.

  This function is used as the auth_function in the lens auth configuration.
  It retrieves the API key from the application configuration and adds it
  to the lens params map.

  ## Parameters

    - `lens` - The lens struct with params

  ## Examples

      lens = %{params: %{module: "account", action: "txlist"}, headers: []}
      EtherscanMonitor.add_api_key(lens)
      # => %{params: %{module: "account", action: "txlist", apikey: "your-key"}, headers: []}
  """
  @spec add_api_key(map()) :: map()
  def add_api_key(lens) do
    api_key = api_key()
    params = Map.put(lens.params, :apikey, api_key)
    %{lens | params: params}
  end

  @doc """
  Gets the Etherscan API key from configuration.

  Returns nil if not configured. Use `api_key!` for a version that raises.

  ## Examples

      iex> EtherscanMonitor.api_key()
      "your-api-key"
  """
  @spec api_key() :: api_key() | nil
  def api_key do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:api_key)
  end

  @doc """
  Gets the Etherscan API key from configuration.

  Raises if the key is not configured.

  ## Examples

      iex> EtherscanMonitor.api_key!()
      "your-api-key"
  """
  @spec api_key!() :: api_key()
  def api_key! do
    case api_key() do
      nil ->
        raise """
        Etherscan API key is not configured.

        Set it in your config/runtime.exs:

            config :lux, Lux.Integrations.EtherscanMonitor,
              api_key: System.get_env("ETHERSCAN_API_KEY")

        Or in your environment file:

            ETHERSCAN_API_KEY="your-api-key"
        """

      key ->
        key
    end
  end

  @doc """
  Builds the full API URL for a given chain and module/action.

  ## Parameters

    - `chain` - Chain atom
    - `module` - Etherscan API module name (e.g., "account", "logs", "contract")
    - `action` - Etherscan API action name (e.g., "txlist", "getLogs")

  ## Examples

      iex> EtherscanMonitor.api_url(:ethereum, "account", "txlist")
      "https://api.etherscan.io/v2/api?module=account&action=txlist"
  """
  @spec api_url(chain(), String.t(), String.t()) :: String.t()
  def api_url(chain \\ :ethereum, module, action) do
    base = base_url(chain)
    "#{base}?module=#{module}&action=#{action}"
  end
end
