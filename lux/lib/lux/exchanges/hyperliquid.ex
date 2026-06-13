defmodule Lux.Exchanges.Hyperliquid do
  @moduledoc """
  Hyperliquid exchange integration for perpetual trading.
  Provides position management, leverage control, risk monitoring,
  order execution, liquidation protection, PnL tracking, and margin management.
  """

  alias Lux.Exchanges.Hyperliquid.API
  alias Lux.Exchanges.Hyperliquid.Positions
  alias Lux.Exchanges.Hyperliquid.Orders
  alias Lux.Exchanges.Hyperliquid.Risk
  alias Lux.Exchanges.Hyperliquid.Margin

  @doc """
  Returns the base URL for Hyperliquid API.
  """
  def base_url, do: "https://api.hyperliquid.xyz"

  @doc """
  Returns the websocket URL for Hyperliquid.
  """
  def websocket_url, do: "wss://api.hyperliquid.xyz/ws"

  @doc """
  Checks if the Hyperliquid integration is configured.
  """
  def configured? do
    Application.get_env(:lux, :hyperliquid) != nil
  end

  @doc """
  Gets the API configuration.
  """
  def config do
    Application.get_env(:lux, :hyperliquid, [])
  end

  @doc """
  Gets a specific config value.
  """
  def config(key, default \\ nil) do
    config() |> Keyword.get(key, default)
  end
end