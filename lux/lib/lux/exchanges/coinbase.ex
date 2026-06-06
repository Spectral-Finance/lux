defmodule Lux.Exchanges.Coinbase do
  @moduledoc """
  Coinbase exchange integration for spot trading and advanced order management.

  Provides REST API and WebSocket integration for:
  - Order management
  - Market data streaming
  - Portfolio tracking
  - Account management
  - Historical data access
  """

  alias Lux.Exchanges.Coinbase.RestClient
  alias Lux.Exchanges.Coinbase.WebSocket
  alias Lux.Exchanges.Coinbase.Orders
  alias Lux.Exchanges.Coinbase.MarketData
  alias Lux.Exchanges.Coinbase.Account

  @doc """
  Returns the base URL for Coinbase API.
  """
  def base_url, do: "https://api.coinbase.com"

  @doc """
  Returns the WebSocket URL for Coinbase.
  """
  def websocket_url, do: "wss://ws-feed.exchange.coinbase.com"

  @doc """
  Returns the sandbox base URL for testing.
  """
  def sandbox_url, do: "https://api-public.sandbox.exchange.coinbase.com"

  # Delegate common functions for convenience
  defdelegate place_order(params), to: Orders
  defdelegate cancel_order(order_id), to: Orders
  defdelegate get_order(order_id), to: Orders
  defdelegate list_orders(params \\ %{}), to: Orders
  defdelegate get_ticker(product_id), to: MarketData
  defdelegate get_order_book(product_id, depth \\ 2), to: MarketData
  defdelegate get_accounts, to: Account
  defdelegate get_account(account_id), to: Account
end