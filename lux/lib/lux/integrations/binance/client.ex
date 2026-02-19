defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for the Binance REST API.

  Supports both public and authenticated (signed) requests for the Binance
  spot and futures APIs. Authentication uses HMAC-SHA256 signatures as
  required by the Binance API.

  ## Configuration

  API keys are read from `Lux.Config`:

      config :lux, :api_keys,
        binance_api_key: "your_api_key",
        binance_secret_key: "your_secret_key"

  ## Examples

      # Public endpoint (no signature required)
      iex> Client.request(:get, "/api/v3/ticker/price", %{symbol: "BTCUSDT"})
      {:ok, %{"symbol" => "BTCUSDT", "price" => "42000.00"}}

      # Signed endpoint
      iex> Client.request(:post, "/api/v3/order", %{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: "0.001",
      ...>   price: "40000",
      ...>   timeInForce: "GTC"
      ...> }, signed: true)
      {:ok, %{"orderId" => 123456, ...}}
  """

  require Logger

  @spot_endpoint "https://api.binance.com"
  @futures_endpoint "https://fapi.binance.com"

  @type endpoint :: :spot | :futures
  @type request_opts :: [
          signed: boolean(),
          endpoint: endpoint(),
          plug: {module(), term()}
        ]

  @doc """
  Makes a request to the Binance API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g., "/api/v3/ticker/price")
    * `params` - Query/body parameters
    * `opts` - Request options

  ## Options

    * `:signed` - Whether to sign the request (default: false)
    * `:endpoint` - Which API to use: `:spot` or `:futures` (default: `:spot`)
    * `:plug` - A plug to use for testing instead of making real HTTP requests
  """
  @spec request(atom(), String.t(), map(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, params \\ %{}, opts \\ []) do
    signed = Keyword.get(opts, :signed, false)
    endpoint_type = Keyword.get(opts, :endpoint, :spot)
    plug = Keyword.get(opts, :plug, nil)

    base_url = base_url(endpoint_type)
    params = if signed, do: sign_params(params), else: params

    headers = build_headers(signed)

    req_opts =
      [
        method: method,
        url: base_url <> path,
        headers: headers,
        retry: false
      ]
      |> add_params(method, params)
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(plug)

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Returns the base URL for the given endpoint type.
  """
  @spec base_url(endpoint()) :: String.t()
  def base_url(:spot), do: @spot_endpoint
  def base_url(:futures), do: @futures_endpoint

  # --- Private helpers ---

  defp build_headers(true) do
    api_key = Lux.Config.binance_api_key()
    [
      {"X-MBX-APIKEY", api_key},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]
  end

  defp build_headers(false) do
    [{"Content-Type", "application/json"}]
  end

  defp sign_params(params) do
    secret = Lux.Config.binance_secret_key()
    timestamp = System.system_time(:millisecond)

    params_with_ts = Map.put(params, :timestamp, timestamp)
    query_string = URI.encode_query(params_with_ts)

    signature =
      :crypto.mac(:hmac, :sha256, secret, query_string)
      |> Base.encode16(case: :lower)

    Map.put(params_with_ts, :signature, signature)
  end

  defp add_params(req_opts, :get, params) do
    Keyword.put(req_opts, :params, params)
  end

  defp add_params(req_opts, _method, params) do
    body = URI.encode_query(params)
    Keyword.put(req_opts, :body, body)
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 429, body: body}}) do
    {:error, {:rate_limited, body}}
  end

  defp handle_response({:ok, %{status: 418, body: body}}) do
    {:error, {:ip_banned, body}}
  end

  defp handle_response({:ok, %{status: status, body: %{"code" => code, "msg" => msg}}}) do
    {:error, {status, code, msg}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    {:error, {:transport_error, reason}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end
end
