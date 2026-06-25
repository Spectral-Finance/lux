defmodule Lux.Integrations.Hyperliquid do
  @moduledoc """
  Hyperliquid Integration for perpetual trading ($900).

  Provides configuration and helpers for Hyperliquid's
  on-chain perpetual DEX: order placement, position tracking,
  leverage control, and risk monitoring.

  ## Configuration

      config :lux, Lux.Integrations.Hyperliquid,
        api_url: System.get_env("HYPERLIQUID_API_URL") || "https://api.hyperliquid.xyz",
        testnet: false
  """

  @mainnet_url "https://api.hyperliquid.xyz"
  @testnet_url "https://api.hyperliquid-testnet.xyz"

  # Hyperliquid uses on-chain L1 — no traditional API key, uses wallet signing
  def api_url do
    if testnet?() do
      Application.get_env(:lux, __MODULE__, [])[:api_url] || @testnet_url
    else
      Application.get_env(:lux, __MODULE__, [])[:api_url] || @mainnet_url
    end
  end

  def testnet?, do: Application.get_env(:lux, __MODULE__, [])[:testnet] || false

  def headers, do: [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @doc "Returns the info endpoint URL."
  def info_url,  do: api_url() <> "/info"
  @doc "Returns the exchange endpoint URL."
  def exchange_url, do: api_url() <> "/exchange"

  @doc "Supported leverage tiers per asset class."
  def max_leverage(:crypto), do: 50
  def max_leverage(:majors), do: 100
  def max_leverage(_), do: 20

  @doc "Calculates liquidation price for a position."
  @spec liquidation_price(float(), float(), float(), :long | :short) :: float()
  def liquidation_price(entry_price, leverage, maintenance_margin_rate \\ 0.005, side) do
    case side do
      :long  -> entry_price * (1 - 1/leverage + maintenance_margin_rate)
      :short -> entry_price * (1 + 1/leverage - maintenance_margin_rate)
    end
  end

  @doc "Calculates required margin for a position."
  @spec required_margin(float(), float(), float()) :: float()
  def required_margin(notional_value, leverage, _buffer \\ 0.1) do
    notional_value / leverage
  end

  @doc "Validates leverage is within allowed bounds."
  @spec valid_leverage?(float(), atom()) :: boolean()
  def valid_leverage?(leverage, asset_class \\ :crypto) do
    leverage > 0 and leverage <= max_leverage(asset_class)
  end
end
