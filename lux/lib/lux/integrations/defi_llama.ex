defmodule Lux.Integrations.DeFiLlama do
  @moduledoc """
  Integration with the DeFiLlama API for DeFi protocol analytics.

  DeFiLlama provides comprehensive DeFi analytics including TVL tracking,
  protocol metrics, yield farming data, and volume analysis across multiple chains.

  ## API Base URL

  Primary: `https://api.llama.fi`

  ## Available Endpoints

  ### TVL Data
  - `/protocol/{name}` - Get TVL data for a specific protocol
  - `/protocols` - List all tracked protocols
  - `/tvl/{protocol}` - Get TVL time series for a protocol
  - `/historical-tvl/{protocol}/{chain}` - Historical TVL by chain
  - `/total2d` - Global DeFi TVL (24h ago)
  - `/current-tvl` - Current total DeFi TVL

  ### Yield Data
  - `/yield` - Aggregate yield data
  - `/yield/{protocol}` - Yield data for specific protocol
  - `/yieldApi` - Detailed yield API data

  ### Volume & Metrics
  - `/volume/{protocol}` - Protocol volume data
  - `/tokens/{chain}` - Token list for a chain

  ## Usage Examples

      # Get current total DeFi TVL
      Lux.Integrations.DeFiLlama.get("/current-tvl")

      # Get TVL for Uniswap
      Lux.Integrations.DeFiLlama.get("/protocol/uniswap")

      # List all protocols
      Lux.Integrations.DeFiLlama.get("/protocols")

      # Get yield data
      Lux.Integrations.DeFiLlama.get("/yield")

      # Get volume for Aave
      Lux.Integrations.DeFiLlama.get("/volume/aave")
  """

  @base_url "https://api.llama.fi"

  @doc """
  Returns the DeFiLlama API base URL.
  """
  @spec base_url() :: String.t()
  def base_url, do: @base_url

  @doc """
  Makes a GET request to the DeFiLlama API.
  """
  @spec get(String.t(), keyword()) :: {:ok, any()} | {:error, any()}
  def get(path, opts \ []) do
    url = @base_url <> path

    req_options =
      [headers: [{"accept", "application/json"}]]
      |> Keyword.merge(Application.get_env(:lux, :defillama_req_options, []))

    case Req.new(req_options)
         |> Req.request(method: :get, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches TVL data for a specific protocol.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.protocol_tvl("uniswap")
      {:ok, %{name: "Uniswap", tvl: [...], currentChain: [...], ...}}

      iex> Lux.Integrations.DeFiLlama.protocol_tvl("aave")
      {:ok, %{...}}
  """
  @spec protocol_tvl(String.t()) :: {:ok, any()} | {:error, any()}
  def protocol_tvl(protocol) when is_binary(protocol) and byte_size(protocol) > 0 do
    get("/protocol/#{URI.encode(protocol)}")
  end

  @doc """
  Fetches the current total DeFi TVL across all protocols.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.total_tvl()
      {:ok, %{totalBreakdown: {...}, ...}}
  """
  @spec total_tvl() :: {:ok, any()} | {:error, any()}
  def total_tvl do
    get("/current-tvl")
  end

  @doc """
  Fetches the DeFi TVL from 24 hours ago for comparison.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.total_tvl_24h()
      {:ok, %{totalBreakdown: {...}, ...}}
  """
  @spec total_tvl_24h() :: {:ok, any()} | {:error, any()}
  def total_tvl_24h do
    get("/total2d")
  end

  @doc """
  Lists all tracked protocols with their metadata.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.protocols()
      {:ok, [%{name: "Uniswap", tvl: 1234..., chainTvls: {...}, ...}, ...]}
  """
  @spec protocols() :: {:ok, any()} | {:error, any()}
  def protocols do
    get("/protocols")
  end

  @doc """
  Fetches yield/farming data from DeFiLlama.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.yield_data()
      {:ok, [%{pool: "...", chain: "...", project: "...", apy": 12.5, ...}, ...]}
  """
  @spec yield_data() :: {:ok, any()} | {:error, any()}
  def yield_data do
    get("/yield")
  end

  @doc """
  Fetches detailed yield API data with more granular information.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.yield_api_data()
      {:ok, %{data: [...], meta: {...}, ...}}
  """
  @spec yield_api_data() :: {:ok, any()} | {:error, any()}
  def yield_api_data do
    get("/yieldApi")
  end

  @doc """
  Fetches volume data for a specific protocol.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.volume("uniswap")
      {:ok, [{timestamp, volume}, ...]}
  """
  @spec volume(String.t()) :: {:ok, any()} | {:error, any()}
  def volume(protocol) when is_binary(protocol) and byte_size(protocol) > 0 do
    get("/volume/#{URI.encode(protocol)}")
  end

  @doc """
  Fetches historical TVL data for a specific protocol.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.historical_tvl("aave", "Ethereum")
      {:ok, [{timestamp, tvl}, ...]}
  """
  @spec historical_tvl(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def historical_tvl(protocol, chain) do
    get("/historical-tvl/#{URI.encode(protocol)}/#{URI.encode(chain)}")
  end

  @doc """
  Fetches the list of tokens for a specific chain.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.tokens("Ethereum")
      {:ok, [%{symbol: "USDC", address: "...", ...}, ...]}
  """
  @spec tokens(String.t()) :: {:ok, any()} | {:error, any()}
  def tokens(chain) when is_binary(chain) and byte_size(chain) > 0 do
    get("/tokens/#{URI.encode(chain)}")
  end

  @doc """
  Fetches chain-level TVL breakdown.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.chains()
      {:ok, [%{name: "Ethereum", tvl: 12345..., ...}, ...]}
  """
  @spec chains() :: {:ok, any()} | {:error, any()}
  def chains do
    get("/chains")
  end

  @doc """
  Fetches TVL for a specific chain.

  ## Examples

      iex> Lux.Integrations.DeFiLlama.chain_tvl("Ethereum")
      {:ok, %{name: "Ethereum", tvl: 12345..., ...}}
  """
  @spec chain_tvl(String.t()) :: {:ok, any()} | {:error, any()}
  def chain_tvl(chain) when is_binary(chain) and byte_size(chain) > 0 do
    get("/chain/#{URI.encode(chain)}")
  end
end
