defmodule Lux.Integrations.Binance do
  @moduledoc """
  Common settings and functions for Binance API integration.

  Supports both Spot (api.binance.com) and Futures (fapi.binance.com) endpoints.

  ## Configuration

      config :lux, :api_keys,
        binance_api_key: "your-api-key",
        binance_secret_key: "your-secret-key"
  """

  @spot_base_url "https://api.binance.com"
  @futures_base_url "https://fapi.binance.com"

  def spot_base_url, do: @spot_base_url
  def futures_base_url, do: @futures_base_url
  def headers, do: [{"Content-Type", "application/json"}]

  def api_key, do: Application.get_env(:lux, :api_keys)[:binance_api_key]
  def secret_key, do: Application.get_env(:lux, :api_keys)[:binance_secret_key]

  @spec sign(String.t()) :: String.t()
  def sign(query_string), do: sign(query_string, secret_key())

  @spec sign(String.t(), String.t()) :: String.t()
  def sign(query_string, secret) do
    :crypto.mac(:hmac, :sha256, secret, query_string)
    |> Base.encode16(case: :lower)
  end

  @spec timestamp() :: integer()
  def timestamp, do: System.system_time(:millisecond)
end
