defmodule Lux.Integrations.Binance do
  @moduledoc """
  Common settings and functions for Binance API integration.

  Supports both Spot and Futures trading via REST API.
  Authentication uses HMAC-SHA256 signed requests.
  """

  @base_url "https://api.binance.com"
  @futures_url "https://fapi.binance.com"
  @testnet_url "https://testnet.binance.vision"
  @futures_testnet_url "https://testnet.binancefuture.com"

  @doc """
  Returns the base URL for Binance Spot API.
  Uses testnet if :binance_testnet is enabled in config.
  """
  def base_url do
    if Application.get_env(:lux, :binance_testnet, false) do
      @testnet_url
    else
      @base_url
    end
  end

  @doc """
  Returns the base URL for Binance Futures API.
  """
  def futures_url do
    if Application.get_env(:lux, :binance_testnet, false) do
      @futures_testnet_url
    else
      @futures_url
    end
  end

  @doc """
  Returns the configured Binance API key.
  """
  def api_key do
    Application.get_env(:lux, :api_keys, [])[:binance_api_key] ||
      System.get_env("BINANCE_API_KEY") ||
      raise "Binance API key not configured. Set :binance_api_key in :lux :api_keys or BINANCE_API_KEY env var."
  end

  @doc """
  Returns the configured Binance API secret.
  """
  def api_secret do
    Application.get_env(:lux, :api_keys, [])[:binance_api_secret] ||
      System.get_env("BINANCE_API_SECRET") ||
      raise "Binance API secret not configured. Set :binance_api_secret in :lux :api_keys or BINANCE_API_SECRET env var."
  end

  @doc """
  Signs a query string with HMAC-SHA256 using the API secret.
  """
  def sign(query_string) do
    secret = api_secret()
    :crypto.mac(:hmac, :sha256, secret, query_string)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Builds a signed query string from a params map, adding timestamp.
  """
  def build_signed_query(params) do
    timestamp = System.system_time(:millisecond)
    query = Map.put(params, :timestamp, timestamp) |> URI.encode_query()
    signature = sign(query)
    query <> "&signature=#{signature}"
  end

  @doc """
  Common headers for authenticated Binance API requests.
  """
  def auth_headers do
    [{"X-MBX-APIKEY", api_key()}, {"Content-Type", "application/json"}]
  end

  @doc """
  Makes a GET request to the Binance API.
  """
  def get(path, params \\ %{}, opts \\ []) do
    base = if Keyword.get(opts, :futures, false), do: futures_url(), else: base_url()
    signed = Keyword.get(opts, :signed, false)

    query =
      if signed do
        "?" <> build_signed_query(params)
      else
        if map_size(params) > 0, do: "?" <> URI.encode_query(params), else: ""
      end

    url = base <> path <> query
    headers = if signed, do: auth_headers(), else: [{"Content-Type", "application/json"}]

    case Req.get(url, headers: headers) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Makes a POST request to the Binance API (always signed).
  """
  def post(path, params \\ %{}, opts \\ []) do
    base = if Keyword.get(opts, :futures, false), do: futures_url(), else: base_url()
    signed_query = build_signed_query(params)
    url = base <> path

    case Req.post(url, headers: auth_headers(), body: signed_query,
           headers: [{"Content-Type", "application/x-www-form-urlencoded"} | auth_headers()]) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Makes a DELETE request to the Binance API (always signed).
  """
  def delete(path, params \\ %{}, opts \\ []) do
    base = if Keyword.get(opts, :futures, false), do: futures_url(), else: base_url()
    query = "?" <> build_signed_query(params)
    url = base <> path <> query

    case Req.delete(url, headers: auth_headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
