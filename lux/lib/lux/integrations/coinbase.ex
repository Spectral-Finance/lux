defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Coinbase Exchange Integration ($750).

  Configuration and request-signing helpers for the
  Coinbase Advanced Trade API (v3) and WebSocket feeds.

  ## Configuration

      config :lux, Lux.Integrations.Coinbase,
        api_key:    System.get_env("COINBASE_API_KEY"),
        api_secret: System.get_env("COINBASE_API_SECRET")
  """

  @base_url "https://api.coinbase.com"
  @ws_url   "wss://advanced-trade-ws.coinbase.com"

  def base_url, do: @base_url
  def ws_url, do: @ws_url

  def api_key do
    Application.get_env(:lux, __MODULE__, [])[:api_key] ||
      System.get_env("COINBASE_API_KEY") || ""
  end

  def api_secret do
    Application.get_env(:lux, __MODULE__, [])[:api_secret] ||
      System.get_env("COINBASE_API_SECRET") || ""
  end

  @doc "Builds signed headers for Coinbase Advanced Trade API."
  @spec signed_headers(String.t(), String.t(), String.t()) :: list()
  def signed_headers(method, path, body \\ "") do
    timestamp = to_string(System.system_time(:second))
    secret    = api_secret()
    message   = timestamp <> String.upcase(method) <> path <> body
    signature = :crypto.mac(:hmac, :sha256, secret, message) |> Base.encode16(case: :lower)
    [
      {"CB-ACCESS-KEY", api_key()},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", timestamp},
      {"Content-Type", "application/json"}
    ]
  end

  # Endpoint helpers
  def products_url,              do: @base_url <> "/api/v3/brokerage/products"
  def product_url(product_id),   do: @base_url <> "/api/v3/brokerage/products/#{product_id}"
  def order_book_url(product_id),do: @base_url <> "/api/v3/brokerage/product_book?product_id=#{product_id}"
  def create_order_url,          do: @base_url <> "/api/v3/brokerage/orders"
  def cancel_orders_url,         do: @base_url <> "/api/v3/brokerage/orders/batch_cancel"
  def list_orders_url,           do: @base_url <> "/api/v3/brokerage/orders/historical/batch"
  def accounts_url,              do: @base_url <> "/api/v3/brokerage/accounts"
  def candles_url(id, start_t, end_t, gran \\ "ONE_HOUR") do
    @base_url <> "/api/v3/brokerage/products/#{id}/candles?start=#{start_t}&end=#{end_t}&granularity=#{gran}"
  end
end
