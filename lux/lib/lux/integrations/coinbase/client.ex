defmodule Lux.Integrations.Coinbase.Client do
  @moduledoc """
  HTTP Client for the Coinbase Advanced Trade REST API.
  """

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
    * `opts` - Request options map
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    signed? = Map.get(opts, :signed, false)
    params = Map.get(opts, :params, %{})
    json_body = Map.get(opts, :json)

    query_string = if params == %{}, do: "", else: "?" <> URI.encode_query(params)
    full_path = path <> query_string

    body_str = if json_body, do: Jason.encode!(json_body), else: ""

    headers =
      if signed? do
        Coinbase.headers(method, full_path, body_str)
      else
        [{"Content-Type", "application/json"}]
      end

    req_opts =
      [
        method: method,
        url: @base_url <> path,
        headers: headers,
        params: params,
        json: json_body
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req = Req.new(req_opts)

    case Req.request(req) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: status, body: %{"error" => error, "message" => message}}} ->
        {:error, {status, error, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
