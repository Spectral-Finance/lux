defmodule Lux.Binance.Client do
  @moduledoc """
  Core HTTP Client for Binance Spot and Futures REST APIs using Req.

  Provides support for:
  - Spot (`api.binance.com`) and Futures (`fapi.binance.com`) endpoints.
  - Mainnet and Testnet environments.
  - Automatic HMAC-SHA256 request signing and header setup via `Lux.Binance.Auth`.
  - Rate limit tracking and 429/418 backoff middleware via `Lux.Binance.RateLimiter`.

  ## Examples

      # Public Spot ticker price request
      iex> Lux.Binance.Client.request(:get, :spot, "/api/v3/ticker/price", %{symbol: "BTCUSDT"})
      {:ok, %{"symbol" => "BTCUSDT", "price" => "95120.50"}}

      # Signed Spot account request
      iex> Lux.Binance.Client.request(:get, :spot, "/api/v3/account", %{}, signed: true, api_key: "key", secret_key: "secret")
      {:ok, %{"balances" => [...]}}
  """

  alias Lux.Binance.Auth
  alias Lux.Binance.RateLimiter

  @type market_type :: :spot | :futures
  @type method :: :get | :post | :put | :delete

  @spot_mainnet "https://api.binance.com"
  @spot_testnet "https://testnet.binance.vision/api"
  @futures_mainnet "https://fapi.binance.com"
  @futures_testnet "https://testnet.binancefuture.com"

  @doc """
  Executes an HTTP request against Binance REST API.

  ## Options
    - `:signed` - Boolean, whether to sign the request (default: `false`).
    - `:api_key` - API key string.
    - `:secret_key` - API secret key string.
    - `:testnet` - Boolean, use testnet URLs (default: `false`).
    - `:recv_window` - Milliseconds window for signed request validity (default: `5000`).
    - `:req_options` - Keyword list passed to `Req` (e.g. `plug: {Req.Test, ...}`).
  """
  @spec request(method(), market_type(), String.t(), map() | keyword() | binary(), keyword()) ::
          {:ok, map() | list()} | {:error, term()}
  def request(method, market_type, path, params \\ %{}, opts \\ []) do
    testnet? = Keyword.get(opts, :testnet, Keyword.get(opts, :testnet?, false))
    base_url = get_base_url(market_type, testnet?)

    api_key = get_api_key(opts)
    secret_key = get_secret_key(opts)
    signed? = Keyword.get(opts, :signed, Keyword.get(opts, :signed?, false))

    cond do
      signed? and (is_nil(secret_key) or secret_key == "") ->
        {:error, :missing_secret_key}

      true ->
        recv_window = Keyword.get(opts, :recv_window, 5000)
        headers = Auth.headers(api_key)
        do_request(method, market_type, base_url, path, params, headers, opts, signed?, secret_key, recv_window)
    end
  end

  @doc """
  Returns the base URL for the given market type and environment.
  """
  @spec get_base_url(market_type(), boolean()) :: String.t()
  def get_base_url(:spot, true), do: @spot_testnet
  def get_base_url(:spot, false), do: @spot_mainnet
  def get_base_url(:futures, true), do: @futures_testnet
  def get_base_url(:futures, false), do: @futures_mainnet

  # Private helpers

  defp do_request(method, market_type, base_url, path, params, headers, opts, signed?, secret_key, recv_window) do
    base_req_opts =
      [
        base_url: base_url,
        headers: headers
      ]
      |> Keyword.merge(Application.get_env(:lux, :req_options, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    req = Req.new(base_req_opts)
    max_retries = Keyword.get(opts, :max_retries, 5)

    execute_with_retry(req, method, path, params, market_type, max_retries, signed?, secret_key, recv_window)
  end

  defp execute_with_retry(req, method, path, params, market_type, retries, signed?, secret_key, recv_window) do
    RateLimiter.wait_if_rate_limited(market_type)

    final_params =
      if signed? do
        Auth.sign_params(params, secret_key, recv_window)
      else
        params
      end

    call_opts = build_req_call_opts(method, path, final_params)

    case Req.request(req, call_opts) do
      {:ok, %{status: status, headers: headers, body: body}} when status in 200..299 ->
        RateLimiter.record_rate_limit(headers, status, market_type)
        {:ok, body}

      {:ok, %{status: status, headers: headers, body: body}} when status in [429, 418] ->
        RateLimiter.record_rate_limit(headers, status, market_type)

        if retries > 0 do
          execute_with_retry(req, method, path, params, market_type, retries - 1, signed?, secret_key, recv_window)
        else
          {:error, %{status: status, body: body}}
        end

      {:ok, %{status: status, headers: headers, body: body}} ->
        RateLimiter.record_rate_limit(headers, status, market_type)
        {:error, %{status: status, body: body}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_req_call_opts(method, path, params) do
    qs = Auth.to_query_string(params)

    url =
      cond do
        qs == "" -> path
        String.contains?(path, "?") -> "#{path}&#{qs}"
        true -> "#{path}?#{qs}"
      end

    [method: method, url: url]
  end

  defp get_api_key(opts) do
    opts[:api_key] ||
      System.get_env("BINANCE_API_KEY") ||
      get_app_config(:binance_api_key)
  end

  defp get_secret_key(opts) do
    opts[:secret_key] ||
      System.get_env("BINANCE_SECRET_KEY") ||
      get_app_config(:binance_secret_key)
  end

  defp get_app_config(key) do
    case Application.get_env(:lux, :api_keys) do
      list when is_list(list) -> Keyword.get(list, key)
      _ -> nil
    end
  end
end
