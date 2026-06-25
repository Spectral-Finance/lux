defmodule Lux.Integrations.Binance do
  @moduledoc """
  Binance Exchange Integration ($750).

  Configuration and helpers for Binance REST API v3
  and WebSocket streams (spot + futures).

  ## Configuration

      config :lux, Lux.Integrations.Binance,
        api_key:    System.get_env("BINANCE_API_KEY"),
        api_secret: System.get_env("BINANCE_API_SECRET"),
        testnet:    false
  """

  @spot_base    "https://api.binance.com"
  @futures_base "https://fapi.binance.com"
  @testnet_spot "https://testnet.binance.vision"
  @testnet_fut  "https://testnet.binancefuture.com"

  @ws_spot    "wss://stream.binance.com:9443/ws"
  @ws_futures "wss://fstream.binance.com/ws"

  def spot_url do
    if testnet?(), do: @testnet_spot, else: @spot_base
  end

  def futures_url do
    if testnet?(), do: @testnet_fut, else: @futures_base
  end

  def ws_spot_url, do: @ws_spot
  def ws_futures_url, do: @ws_futures
  def testnet?, do: Application.get_env(:lux, __MODULE__, [])[:testnet] || false

  def api_key do
    Application.get_env(:lux, __MODULE__, [])[:api_key] ||
      System.get_env("BINANCE_API_KEY") || ""
  end

  def api_secret do
    Application.get_env(:lux, __MODULE__, [])[:api_secret] ||
      System.get_env("BINANCE_API_SECRET") || ""
  end

  @doc "Returns headers including X-MBX-APIKEY."
  def headers do
    [{"X-MBX-APIKEY", api_key()},
     {"Content-Type", "application/x-www-form-urlencoded"}]
  end

  @doc "Signs query parameters with HMAC-SHA256."
  @spec sign_params(String.t()) :: String.t()
  def sign_params(query_string) do
    secret = api_secret()
    :crypto.mac(:hmac, :sha256, secret, query_string)
    |> Base.encode16(case: :lower)
  end

  @doc "Adds timestamp and signature to params map."
  @spec signed_params(map()) :: map()
  def signed_params(params) do
    ts  = System.system_time(:millisecond)
    qs  = params |> Map.put(:timestamp, ts) |> URI.encode_query()
    sig = sign_params(qs)
    Map.merge(params, %{timestamp: ts, signature: sig})
  end

  # Endpoint helpers
  def ticker_url(symbol),    do: spot_url() <> "/api/v3/ticker/price?symbol=#{symbol}"
  def order_book_url(symbol), do: spot_url() <> "/api/v3/depth?symbol=#{symbol}&limit=20"
  def klines_url(symbol, interval \\ "1h"), do: spot_url() <> "/api/v3/klines?symbol=#{symbol}&interval=#{interval}&limit=100"
  def new_order_url, do: spot_url() <> "/api/v3/order"
  def cancel_order_url, do: spot_url() <> "/api/v3/order"
  def account_url, do: spot_url() <> "/api/v3/account"
end
