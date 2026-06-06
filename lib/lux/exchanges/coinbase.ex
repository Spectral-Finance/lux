defmodule Lux.Exchanges.Coinbase do
  @moduledoc """
  Coinbase Exchange integration for spot trading and advanced order management.

  This module provides REST API and WebSocket integration for Coinbase Pro/Advanced Trade.
  """

  alias Lux.Exchanges.Coinbase.Rest
  alias Lux.Exchanges.Coinbase.WebSocket
  alias Lux.Exchanges.Coinbase.OrderManager
  alias Lux.Exchanges.Coinbase.MarketData
  alias Lux.Exchanges.Coinbase.Account

  @doc """
  Starts the Coinbase exchange integration.
  """
  def start_link(opts \\ []) do
    children = [
      {WebSocket, opts[:websocket] || []},
      {OrderManager, opts[:order_manager] || []},
      {MarketData, opts[:market_data] || []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end

  @doc """
  Places a new order on Coinbase.
  """
  def place_order(order_params) do
    OrderManager.place_order(order_params)
  end

  @doc """
  Cancels an existing order.
  """
  def cancel_order(order_id) do
    OrderManager.cancel_order(order_id)
  end

  @doc """
  Gets account information and balances.
  """
  def get_account_info do
    Account.get_info()
  end

  @doc """
  Gets market data for a trading pair.
  """
  def get_market_data(pair) do
    MarketData.get_ticker(pair)
  end

  @doc """
  Gets historical trades for a pair.
  """
  def get_historical_trades(pair, params \\ []) do
    MarketData.get_trades(pair, params)
  end

  @doc """
  Gets order book for a pair.
  """
  def get_order_book(pair, level \\ 1) do
    MarketData.get_order_book(pair, level)
  end

  @doc """
  Subscribes to WebSocket feeds.
  Supported channels: :ticker, :level2, :matches, :user
  """
  def subscribe(channel, pairs, callback) do
    WebSocket.subscribe(channel, pairs, callback)
  end

  @doc """
  Unsubscribes from WebSocket feeds.
  """
  def unsubscribe(channel, pairs) do
    WebSocket.unsubscribe(channel, pairs)
  end
end