defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for Binance REST API.
  Supports both Spot and USD(S)-M Futures endpoints.
  """

  require Logger
  alias Lux.Integrations.Binance

  @spot_endpoint "https://api.binance.com"
  @futures_endpoint "https://fapi.binance.com"

  @type network :: :spot | :futures
  @type request_opts :: %{
    optional(:network) => network(),
    optional(:signed) => boolean(),
    optional(:json) => map(),
    optional(:params) => map()
  }

  @doc """
  Makes a request to the Binance API.

  ## Parameters
    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/api/v3/ticker/price")
    * `opts` - Request options
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    network = opts[:network] || :spot
    signed? = Map.get(opts, :signed, false)
    params = opts[:params] || %{}

    base_url = case network do
      :spot -> @spot_endpoint
      :futures -> @futures_endpoint
    end

    headers = [
      {"Content-Type", "application/json"}
    ]

    api_key = Application.get_env(:lux, :api_keys)[:binance_api_key]
    headers = if api_key, do: [{"X-MBX-APIKEY", api_key} | headers], else: headers

    params = if signed? do
      Binance.sign_params(params)
    else
      params
    end

    req =
      Req.new(
        method: method,
        url: base_url <> path,
        headers: headers,
        params: params,
        json: opts[:json]
      )
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()

    case Req.request(req) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: status, body: %{"msg" => message, "code" => code}}} ->
        {:error, {status, code, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
