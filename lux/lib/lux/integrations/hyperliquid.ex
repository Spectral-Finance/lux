defmodule Lux.Integrations.Hyperliquid do
  @moduledoc """
  Integration with the Hyperliquid exchange for perpetual trading.

  Hyperliquid is a decentralized perpetual exchange that provides order execution,
  position management, leverage control, and risk monitoring capabilities.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, :accounts,
        hyperliquid_private_key: System.get_env("HYPERLIQUID_PRIVATE_KEY"),
        hyperliquid_address: System.get_env("HYPERLIQUID_ADDRESS"),
        hyperliquid_api_url: System.get_env("HYPERLIQUID_API_URL") || "https://api.hyperliquid.xyz"

  ## API Endpoints

  The module supports different API endpoints:
  - Mainnet: `https://api.hyperliquid.xyz`
  - Testnet: `https://api.hyperliquid-testnet.xyz`

  ## Authentication

  Authentication is handled via Ethereum wallet signatures. The private key is used
  to sign requests for order placement, modification, and cancellation.

  ## Usage Examples

  ### Basic Setup

      alias Lux.Integrations.Hyperliquid

      # Get configured base URL
      base_url = Hyperliquid.base_url()  # => "https://api.hyperliquid.xyz"

      # Get default headers
      headers = Hyperliquid.headers()

  ### Using with Lenses

      defmodule MyApp.Lenses.HyperliquidExample do
        use Lux.Lens,
          name: "Hyperliquid Example",
          url: "\#{Hyperliquid.base_url()}/info",
          method: :post,
          headers: Hyperliquid.headers()
      end

  ## Available Lenses

  1. `Lux.Lenses.Hyperliquid.GetMarkets` - Fetches available perpetual markets
  2. `Lux.Lenses.Hyperliquid.GetOrderBook` - Fetches order book for a market
  3. `Lux.Lenses.Hyperliquid.GetPositions` - Fetches user positions
  4. `Lux.Lenses.Hyperliquid.GetAccountState` - Fetches account state and margin info

  ## Available Prisms

  1. `Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism` - Places orders
  2. `Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism` - Cancels orders
  3. `Lux.Prisms.Hyperliquid.ModifyOrderPrism` - Modifies existing orders
  4. `Lux.Prisms.Hyperliquid.SetLeveragePrism` - Sets leverage for trading pairs

  ## Response Formats

  ### Markets Response
      %{
        name: "ETH",
        sz_decimals: 4,
        max_leverage: 50,
        mark_px: "2800.0",
        funding: "0.0001",
        open_interest: "1000000.0",
        prev_day_px: "2750.0",
        volume_24h: "50000000.0"
      }

  ### Account State Response
      %{
        margin_summary: %{
          account_value: "10000.0",
          total_margin_used: "1000.0",
          total_ntl_pos: "2000.0"
        },
        asset_positions: [
          %{
            coin: "ETH",
            entry_px: "2800.0",
            leverage: "2.0",
            liquidation_px: "1400.0",
            size: "1.0",
            unrealized_pnl: "100.0"
          }
        ]
      }
  """

  require Logger

  @type headers :: [{String.t(), String.t()}]

  @info_endpoint "/info"
  @exchange_endpoint "/exchange"

  @doc """
  Gets the configured Hyperliquid API base URL.
  Defaults to "https://api.hyperliquid.xyz" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:lux, :accounts, [])
    |> Keyword.get(:hyperliquid_api_url, "https://api.hyperliquid.xyz")
  end

  @doc """
  Gets the info API endpoint URL.
  """
  @spec info_url() :: String.t()
  def info_url do
    "#{base_url()}#{@info_endpoint}"
  end

  @doc """
  Gets the exchange API endpoint URL.
  """
  @spec exchange_url() :: String.t()
  def exchange_url do
    "#{base_url()}#{@exchange_endpoint}"
  end

  @doc """
  Gets the default headers for Hyperliquid API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Makes an info API request to Hyperliquid.

  ## Parameters
    - `request_type` - The type of info request (e.g., "meta", "allMids", "clearinghouseState")
    - `params` - Additional parameters for the request

  ## Examples

      iex> Hyperliquid.info_request("meta")
      {:ok, %{"universe" => [...]}}

      iex> Hyperliquid.info_request("clearinghouseState", %{"user" => "0x..."})
      {:ok, %{"assetPositions" => [...], "crossMarginSummary" => %{...}}}
  """
  @spec info_request(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def info_request(request_type, params \\ %{}) do
    body = Map.merge(%{"type" => request_type}, params)

    [url: info_url(), headers: headers(), max_retries: 2]
    |> Keyword.merge(Application.get_env(:lux, :req_options, []))
    |> Req.new()
    |> Req.request(method: :post, json: body)
    |> handle_response()
  end

  @doc """
  Makes an exchange API request to Hyperliquid.
  Used for order placement, cancellation, modification, and leverage changes.

  ## Parameters
    - `action` - The exchange action to perform
    - `nonce` - Request nonce for replay protection
    - `signature` - EIP-712 signature

  ## Examples

      iex> Hyperliquid.exchange_request(action, nonce, signature, vault_address)
      {:ok, %{"status" => "ok", ...}}
  """
  @spec exchange_request(map(), integer(), map(), String.t() | nil) :: {:ok, map()} | {:error, any()}
  def exchange_request(action, nonce, signature, vault_address \\ nil) do
    body = %{
      "action" => action,
      "nonce" => nonce,
      "signature" => signature
    }

    body = if vault_address, do: Map.put(body, "vaultAddress", vault_address), else: body

    [url: exchange_url(), headers: headers(), max_retries: 0]
    |> Keyword.merge(Application.get_env(:lux, :req_options, []))
    |> Req.new()
    |> Req.request(method: :post, json: body)
    |> handle_response()
  end

  @doc """
  Gets the configured Hyperliquid private key.
  """
  @spec private_key() :: {:ok, String.t()} | {:error, :missing_private_key}
  def private_key do
    case Application.get_env(:lux, :accounts, []) |> Keyword.get(:hyperliquid_private_key) do
      nil -> {:error, :missing_private_key}
      key -> {:ok, key}
    end
  end

  @doc """
  Gets the configured Hyperliquid account address.
  """
  @spec account_address() :: String.t()
  def account_address do
    Application.get_env(:lux, :accounts, [])
    |> Keyword.get(:hyperliquid_address, "")
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Hyperliquid API error (status #{status}): #{inspect(body)}")
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    Logger.error("Hyperliquid transport error: #{inspect(reason)}")
    {:error, inspect(reason)}
  end

  defp handle_response({:error, error}) do
    Logger.error("Hyperliquid request error: #{inspect(error)}")
    {:error, inspect(error)}
  end
end
