defmodule Lux.Integrations.Curve do
  @moduledoc """
  Integration with Curve Finance API for stablecoin pool management and yield optimization.

  Curve Finance is a decentralized exchange optimized for stablecoin trading with low
  slippage. This integration provides access to pool data, gauge information, CRV rewards,
  and deposit/withdrawal operations.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Curve,
        api_url: System.get_env("CURVE_API_URL") || "https://api.curve.fi/v1",
        rpc_url: System.get_env("CURVE_RPC_URL") || "https://eth.llamarpc.com",
        chain_id: System.get_env("CURVE_CHAIN_ID") || "1"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      CURVE_API_URL="https://api.curve.fi/v1"
      CURVE_RPC_URL="https://eth.llamarpc.com"
      CURVE_CHAIN_ID="1"

  ## Supported Networks (chain_id)

  - `"1"` - Ethereum Mainnet
  - `"137"` - Polygon
  - `"42161"` - Arbitrum
  - `"43114"` - Avalanche
  - `"8453"` - Base
  - `"56"` - BNB Chain

  ## Usage Examples

  ### Basic Setup

      # In your lens or module:
      alias Lux.Integrations.Curve

      # Get configured API URL
      api_url = Curve.api_url()  # => "https://api.curve.fi/v1"

      # Get configured RPC URL
      rpc_url = Curve.rpc_url()  # => "https://eth.llamarpc.com"

      # Get chain ID
      chain_id = Curve.chain_id()  # => "1"

      # Get default headers
      headers = Curve.headers()
      # => [{"content-type", "application/json"}]

  ### Using with Lenses

      defmodule MyApp.Lenses.CurvePoolLens do
        use Lux.Lens,
          name: "Curve Pool Data",
          url: "\#{Curve.api_url()}/\#{Curve.chain_id()}/pools/eth/list",
          method: :get,
          headers: Curve.headers()
      end

  ## Curve Finance API Endpoints Used

  1. `GET /:chainName/pools/eth/list` - List all Ethereum pools
  2. `GET /:chainName/pools/:poolName` - Get specific pool details
  3. `GET /:chainName/pools/eth/fraxswap` - FraxSwap pool data
  4. `GET /:chainName/pools/eth/yearn` - Yearn pool data
  5. `GET /:chainName/pools/eth/cvxcrv` - CVXCRV pool data
  6. `GET /:chainName/pools/eth/compound` - Compound pool data
  7. `GET /:chainName/pools/eth/aave` - Aave pool data
  8. `GET /:chainName/pools/eth/skyv2` - Sky v2 pool data

  ## Response Formats

  ### Pool List Response
      %{
        "status" => "success",
        "result" => [
          %{
            "name" => "3crypto",
            "coins" => ["DAI", "USDC", "USDT"],
            "usdTotal" => 150000000.0,
            "apr" => %{
              "base" => 0.5,
              "rewards" => 2.3,
              "total" => 2.8
            }
          }
        ]
      }

  ### Deposit Response
      %{
        "status" => "success",
        "result" => %{
          "txHash" => "0x...",
          "amount" => "1000.0",
          "pool" => "3crypto",
          "chain" => "eth"
        }
      }
  """

  @type api_key :: String.t()
  @type rpc_url :: String.t()
  @type chain_id :: String.t()
  @type headers :: [{String.t(), String.t()}]
  @type pool_name :: String.t()

  require Logger

  @doc """
  Gets the configured Curve API URL.
  Defaults to "https://api.curve.fi/v1" if not configured.
  """
  @spec api_url() :: String.t()
  def api_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:api_url, "https://api.curve.fi/v1")
  end

  @doc """
  Gets the configured Curve RPC URL.
  Defaults to Ethereum public RPC if not configured.
  """
  @spec rpc_url() :: String.t()
  def rpc_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:rpc_url, "https://eth.llamarpc.com")
  end

  @doc """
  Gets the configured chain ID.
  Defaults to "1" (Ethereum mainnet).
  """
  @spec chain_id() :: String.t()
  def chain_id do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:chain_id, "1")
  end

  @doc """
  Gets the chain name from chain ID for API calls.
  """
  @spec chain_name() :: String.t()
  def chain_name do
    case chain_id() do
      "137" -> "polygon"
      "42161" -> "arbitrum"
      "43114" -> "avax"
      "8453" -> "base"
      "56" -> "bsc"
      _ -> "eth"
    end
  end

  @doc """
  Gets the default headers for Curve API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for Curve API requests.
  Curve's public API does not require authentication.
  """
  @spec auth() :: map()
  def auth do
    %{}
  end

  @doc """
  Returns the full base URL for a given chain name and endpoint.
  """
  @spec base_url(String.t()) :: String.t()
  def base_url(chain_name \ chain_name()) do
    "#{api_url()}/#{chain_name}"
  end

  @doc """
  Gets the Curve 3CRV pool address on the configured chain.
  """
  @spec three_crvg_pool_address() :: String.t()
  def three_crvg_pool_address do
    case chain_id() do
      "137" -> "0x445fe580ef8d70ff569ab36e80c647af338db351"
      "42161" -> "0x7f90122bf0700f9e7e1f1887bc3baf4b40ab75ed"
      _ -> "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
    end
  end

  @doc """
  Gets the Curve CRV reward token address.
  """
  @spec crv_token_address() :: String.t()
  def crv_token_address do
    case chain_id() do
      "137" -> "0x172370d5Cd63279eFa6d502DAB29171933a610AF"
      "42161" -> "0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978"
      _ -> "0xD533a949740bb3306d119CC777fa900bA034cd52"
    end
  end

  @doc """
  Gets the Curve Gauge controller address.
  """
  @spec gauge_controller_address() :: String.t()
  def gauge_controller_address do
    case chain_id() do
      "137" -> "0x95211YaddressPlaceholder"
      "42161" -> "0x0000000000000000000000000000000000000000"
      _ -> "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"
    end
  end

  @doc """
  Builds the URL for listing pools on the configured chain.
  """
  @spec pools_list_url() :: String.t()
  def pools_list_url do
    "#{base_url()}/pools/#{chain_name()}/list"
  end

  @doc """
  Builds the URL for getting a specific pool's details.
  """
  @spec pool_detail_url(String.t()) :: String.t()
  def pool_detail_url(pool_name) do
    "#{base_url()}/pools/#{pool_name}"
  end

  @doc """
  Builds the URL for getting deposit data for a pool.
  """
  @spec deposit_url(String.t()) :: String.t()
  def deposit_url(pool_name) do
    "#{base_url()}/pools/#{pool_name}/deposit"
  end

  @doc """
  Builds the URL for getting withdraw data for a pool.
  """
  @spec withdraw_url(String.t()) :: String.t()
  def withdraw_url(pool_name) do
    "#{base_url()}/pools/#{pool_name}/withdraw"
  end

  @doc """
  Builds the URL for getting swap data for a pool.
  """
  @spec swap_url(String.t()) :: String.t()
  def swap_url(pool_name) do
    "#{base_url()}/pools/#{pool_name}/swap"
  end

  @doc """
  Builds the URL for getting gauge staking data.
  """
  @spec gauge_stake_url() :: String.t()
  def gauge_stake_url do
    "#{base_url()}/gauge/stake"
  end

  @doc """
  Builds the URL for getting claim rewards data.
  """
  @spec claim_rewards_url() :: String.t()
  def claim_rewards_url do
    "#{base_url()}/rewards/claim"
  end

  @doc """
  Builds the URL for getting pool analytics/yield data.
  """
  @spec pool_analytics_url() :: String.t()
  def pool_analytics_url do
    "#{base_url()}/pools/analytics"
  end
end
