defmodule Lux.Integrations.Binance do
  @moduledoc """
  Common settings and functions for Binance API integration.

  Supports both public endpoints (market data) and private endpoints
  (trading, account) requiring HMAC-SHA256 signed requests.
  """

  @base_url "https://api.binance.com"

  def base_url, do: @base_url

  @doc "Common headers for public Binance API calls."
  def headers, do: [{"Content-Type", "application/json"}]

  @doc "Auth settings for private Binance API calls (requires API key)."
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key_header/1
    }
  end

  @doc "Adds the X-MBX-APIKEY header from application config."
  @spec add_api_key_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_api_key_header(%Plug.Conn{} = conn) do
    api_key = Lux.Config.binance_api_key()
    Plug.Conn.put_req_header(conn, "x-mbx-apikey", api_key)
  end
end
