defmodule Lux.Integrations.Coinbase.Client do
  @moduledoc """
  HTTP client for Coinbase Advanced Trade REST API.
  """

  require Logger
  alias Lux.Integrations.Coinbase

  @base_url "https://api.coinbase.com"

  @type request_opts :: %{
    optional(:signed) => boolean(),
    optional(:json) => map(),
    optional(:params) => map()
  }

  @doc """
  Makes a request to the Coinbase API.

  ## Parameters
    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/api/v3/brokerage/accounts")
    * `opts` - Request options
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    signed? = Map.get(opts, :signed, false)
    params = opts[:params] || %{}
    body_json = opts[:json]
    
    # Add query params to path if present
    query_string = if params != %{}, do: "?" <> URI.encode_query(params), else: ""
    full_path = path <> query_string
    
    body_str = if body_json, do: Jason.encode!(body_json), else: ""

    headers = if signed? do
      Coinbase.sign_request(method, full_path, body_str)
    else
      [{"Content-Type", "application/json"}]
    end

    req =
      Req.new(
        method: method,
        url: @base_url <> full_path,
        headers: headers,
        json: body_json
      )
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Req.new()

    case Req.request(req) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
