defmodule Lux.Integrations.Curve do
  @moduledoc """
  Integration with the Curve Finance API for accessing pool data and prices.

  Curve Finance is a decentralized exchange (DEX) liquidity pool on Ethereum and other
  EVM-compatible chains, optimized for stablecoin trading with low slippage.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Curve,
        base_url: System.get_env("CURVE_API_URL") || "https://api.curve.fi/api"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      CURVE_API_URL="https://api.curve.fi/api"  # Optional, defaults to this value

  ## Supported Networks

  The module supports the following blockchain networks:
  - `"ethereum"` - Ethereum mainnet
  - `"polygon"` - Polygon
  - `"arbitrum"` - Arbitrum
  - `"optimism"` - Optimism
  - `"avalanche"` - Avalanche
  - `"fantom"` - Fantom
  - `"gnosis"` - Gnosis Chain
  - `"celo"` - Celo
  - `"base"` - Base

  ## Usage Examples

  ### Basic Setup

      alias Lux.Integrations.Curve

      # Get configured base URL
      base_url = Curve.base_url()  # => "https://api.curve.fi/api"

  ### Using with Lenses

      defmodule MyApp.Lenses.CurveExample do
        use Lux.Lens,
          name: "Curve Example",
          url: "\#{Curve.base_url()}/getPools/ethereum",
          method: :get,
          headers: Curve.headers()
      end

  ## Available Lenses

  The integration includes three main lenses:

  1. `Lux.Lenses.Curve.GetPoolsLens` - Fetches all Curve pools for a network
     ```elixir
     {:ok, pools} = Lux.Lenses.Curve.GetPoolsLens.focus(%{network: "ethereum"})
     ```

  2. `Lux.Lenses.Curve.GetPoolInfoLens` - Fetches specific pool information
     ```elixir
     {:ok, pool} = Lux.Lenses.Curve.GetPoolInfoLens.focus(%{
       pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
     })
     ```

  3. `Lux.Lenses.Curve.GetPricesLens` - Fetches pool prices from subgraph data
     ```elixir
     {:ok, prices} = Lux.Lenses.Curve.GetPricesLens.focus(%{network: "ethereum"})
     ```
  """

  @type base_url :: String.t()
  @type network :: String.t()
  @type headers :: [{String.t(), String.t()}]

  @doc """
  Gets the configured Curve API base URL.
  Defaults to "https://api.curve.fi/api" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.curve.fi/api")
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
  Validates a network slug against the list of supported networks.
  """
  @spec valid_network?(String.t()) :: boolean()
  def valid_network?(network) do
    network in ~w(ethereum polygon arbitrum optimism avalanche fantom gnosis celo base)
  end
end
