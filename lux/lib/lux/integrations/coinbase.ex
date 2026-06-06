defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Coinbase Exchange integration for spot trading and advanced order management.

  Provides REST API and WebSocket integration for:
  - Order placement and management
  - Market data streaming
  - Portfolio tracking
  - Account management
  - Historical data access
  """

  alias Lux.Integrations.Coinbase.RestClient
  alias Lux.Integrations.Coinbase.WebSocket
  alias Lux.Integrations.Coinbase.Orders
  alias Lux.Integrations.Coinbase.Account
  alias Lux.Integrations.Coinbase.MarketData

  @type api_key :: String.t()
  @type api_secret :: String.t()
  @type passphrase :: String.t()
  @type sandbox :: boolean()
  @type config :: %{
          optional(:api_key) => api_key(),
          optional(:api_secret) => api_secret(),
          optional(:passphrase) => passphrase(),
          optional(:sandbox) => sandbox()
        }

  @doc """
  Returns the default configuration for the Coinbase integration.
  """
  @specifice config() :: config()
  def config do
    %{
      api_key: System.get_env("COINBASE_API_KEY"),
      api_secret: System.get_env("COINBASE_API_SECRET"),
      passphrase: System.get_env("COINBASE_PASSPHRASE"),
      sandbox: System.get_env("COINBASE_SANDBOX", "false") == "true"
    }
  end

  @doc """
  Returns the base URL for the Coinbase API based on environment.
  """
  @spec base_url() :: String.t()
  def base_url do
    if config().sandbox do
      "https://api-public.sandbox.pro.coinbase.com"
    else
      "https://api.pro.coinbase.com"
    end
  end

  @doc """
  Returns the WebSocket URL for the Coinbase API.
  """
  @spec websocket_url() :: String.t()
  def websocket_url do
    if config().sandbox do
      "wss://ws-feed-public.sandbox.pro.coinbase.com"
    else
      "wss://ws-feed.pro.coinbase.com"
    end
  end

  # Order Management Delegates

  @doc """
  Places a new order on Coinbase.
  """
  defdelegate place_order(params, opts \\ []), to: Orders

  @doc """
  Cancels an existing order.
  """
  defdelegate cancel_order(order_id, opts \\ []), to: Orders

  @doc """
  Lists all open orders.
  """
  defdelegate list_orders(opts \\ []), to: Orders

  @doc """
  Gets details of a specific order.
  """
  defdelegate get_order(order_id, opts \\ []), to: Orders

  # Account Management Delegates

  @doc """
  Lists all accounts for the authenticated user.
  """
  defdelegate list_accounts(opts \\ []), to: Account

  @doc """
  Gets details of a specific account.
  """
  defdelegate get_account(account_id, opts \\ []), to: Account

  @doc """
  Gets the account history.
  """
  defdelegate get_account_history(account_id, opts \\ []), to: Account

  @doc """
  Gets account holds.
  """
  defdelegate get_account_holds(account_id, opts \\ []), to: Account

  # Market Data Delegates

  @doc """
  Gets available products (trading pairs).
  """
  defdelegate get_products(opts \\ []), to: MarketData

  @doc """
  Gets details of a specific product.
  """
  defdelegate get_product(product_id, opts \\ []), to: MarketData

  @doc """
  Gets the order book for a product.
  """
  defdelegate get_order_book(product_id, level \\ 1, opts \\ []), to: MarketData

  @doc """
  Gets ticker information for a product.
  """
  defdelegate get_ticker(product_id, opts \\ []), to: MarketData

  @doc """
  Gets trades for a product.
  """
  defdelegate get_trades(product_id, opts \\ []), to: MarketData

  @doc """
  Gets historical rates (candles) for a product.
  """
  defdelegate get_historic_rates(product_id, opts \\ []), to: MarketData

  # WebSocket

  @doc """
  Starts a WebSocket connection for real-time data.
  """
  def start_websocket(handler_module, channels, opts \\ []) do
    WebSocket.start_link(handler_module, channels, opts)
  end
end