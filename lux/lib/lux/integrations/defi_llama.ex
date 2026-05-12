defmodule Lux.Integrations.DeFiLlama do
  @moduledoc """
  Integration with the DeFiLlama API for accessing DeFi protocol data, TVL, token prices, and yield pools.

  DeFiLlama is a leading DeFi analytics platform that provides comprehensive data on:
  - Protocol Total Value Locked (TVL) across multiple chains
  - Historical TVL data for individual protocols
  - Current token prices
  - Yield farming pool data

  ## Configuration

  DeFiLlama API is free and requires no API key or authentication.

  ## Base URLs

  The module supports two base URLs:
  - `api.llama.fi` - For protocol TVL data and token prices
  - `yields.llama.fi` - For yield pool data

  ## Usage Examples

  ### Basic Setup

      alias Lux.Integrations.DeFiLlama

      # Get base URL for protocol data
      DeFiLlama.base_url()  # => "https://api.llama.fi"

      # Get base URL for yields data
      DeFiLlama.yields_base_url()  # => "https://yields.llama.fi"

  ### Using with Lenses

      defmodule MyApp.Lenses.Protocols do
        use Lux.Lens,
          name: "DeFiLlama Protocols",
          url: "\#{DeFiLlama.base_url()}/protocols",
          method: :get,
          headers: DeFiLlama.headers()
      end

  ## Available Lenses

  The integration includes four main lenses:

  1. `Lux.Lenses.DeFiLlama.ProtocolsLens` - Fetches all protocols with TVL data
     ```elixir
     {:ok, protocols} = Lux.Lenses.DeFiLlama.ProtocolsLens.focus(%{})
     ```

  2. `Lux.Lenses.DeFiLlama.ProtocolTVLLens` - Fetches TVL for a specific protocol
     ```elixir
     {:ok, tvl_data} = Lux.Lenses.DeFiLlama.ProtocolTVLLens.focus(%{protocol: "aave"})
     ```

  3. `Lux.Lenses.DeFiLlama.PricesLens` - Fetches current token prices
     ```elixir
     {:ok, prices} = Lux.Lenses.DeFiLlama.PricesLens.focus(%{coins: "ethereum:0x...", ...})
     ```

  4. `Lux.Lenses.DeFiLlama.YieldsLens` - Fetches yield pool data
     ```elixir
     {:ok, pools} = Lux.Lenses.DeFiLlama.YieldsLens.focus(%{})
     ```
  """

  @doc """
  Gets the base URL for DeFiLlama protocol data API.
  """
  @spec base_url() :: String.t()
  def base_url, do: "https://api.llama.fi"

  @doc """
  Gets the base URL for DeFiLlama yields data API.
  """
  @spec yields_base_url() :: String.t()
  def yields_base_url, do: "https://yields.llama.fi"

  @doc """
  Gets the default headers for DeFiLlama API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"accept", "application/json"}
    ]
  end
end
