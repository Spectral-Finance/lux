defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP Client for the Binance REST API.
  Supports both Spot and Futures endpoints.
  """

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
    * `opts` - Request options map
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    network = Map.get(opts, :network, :spot)
    signed? = Map.get(opts, :signed, false)
    params = Map.get(opts, :params, %{})

    base_url =
      case network do
        :spot -> @spot_endpoint
        :futures -> @futures_endpoint
      end

    headers = Binance.headers()

    params =
      if signed? do
        Binance.sign_params(params)
      else
        params
      end

    req_opts =
      [
        method: method,
        url: base_url <> path,
        headers: headers,
        params: params,
        json: Map.get(opts, :json)
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req = Req.new(req_opts)

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
