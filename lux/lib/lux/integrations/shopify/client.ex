defmodule Lux.Integrations.Shopify.Client do
  @moduledoc """
  HTTP client for the Shopify Admin API.

  Supports both the REST Admin API (resource-oriented) and the GraphQL Admin
  API (single endpoint). Handles:

    * access-token authentication via `X-Shopify-Access-Token`
    * rate-limit accounting via the `Shopify-Shop-Api-Call-Limit` header
    * automatic retry on `429 Too Many Requests` (honouring `Retry-After`)
    * structured error returns

  ## Examples

      iex> Shopify.Client.request(:get, "/products.json")
      {:ok, %{"products" => [...]}}

      iex> Shopify.Client.graphql("{ shop { name } }")
      {:ok, %{"data" => %{"shop" => %{"name" => "My Shop"}}}}
  """

  alias Lux.Integrations.Shopify
  require Logger

  @type request_opts :: %{
    optional(:access_token) => String.t(),
    optional(:json) => map(),
    optional(:params) => keyword() | map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:max_retries) => non_neg_integer(),
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a REST request to the Shopify Admin API.

  ## Parameters

    * `method` - HTTP method (`:get`, `:post`, `:put`, `:delete`)
    * `path` - API path relative to the versioned admin API root
      (e.g. `"/products.json"`)
    * `opts` - request options (see Options section)

  ## Options

    * `:access_token` - Admin API access token (defaults to configured token)
    * `:json` - request body for POST/PUT requests
    * `:params` - query parameters
    * `:headers` - additional headers
    * `:max_retries` - maximum retries on 429 (defaults to 3)
    * `:plug` - a plug to use for testing instead of real HTTP requests

  ## Examples

      iex> Shopify.Client.request(:get, "/products.json", %{params: [limit: 50]})
      {:ok, %{"products" => [%{"id" => 1}]}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    url = Shopify.admin_api_url() <> path
    do_request(method, url, opts, opts[:max_retries] || 3)
  end

  @doc """
  Makes a GraphQL request to the Shopify GraphQL Admin API.

  `query` may be a query string or a `%{query: ..., variables: ...}` map.
  """
  @spec graphql(String.t() | map(), request_opts()) :: {:ok, map()} | {:error, term()}
  def graphql(query, opts \\ %{}) do
    body =
      case query do
        %{query: _} = q -> q
        q -> %{query: q}
      end

    url = "#{Shopify.admin_api_url()}/graphql.json"
    do_request(:post, url, Map.put(opts, :json, body), opts[:max_retries] || 3)
  end

  defp do_request(_method, _url, _opts, retries) when retries < 0 do
    {:error, :max_retries_exceeded}
  end

  defp do_request(method, url, opts, retries) do
    token = opts[:access_token] || Shopify.access_token()

    request_opts = [
      method: method,
      url: url,
      headers: [
        {"X-Shopify-Access-Token", token},
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ] ++ (opts[:headers] || []),
      params: Map.to_list(opts[:params] || []),
      json: opts[:json]
    ]

    request_opts =
      request_opts
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])

    request_opts
    |> Req.new()
    |> Req.request()
    |> handle_response(method, url, opts, retries)
  end

  defp handle_response({:ok, %{status: status} = response}, _method, _url, _opts, _retries)
       when status in 200..299 do
    log_rate_limit(response)
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: 429, headers: headers}}, method, url, opts, retries) do
    log_rate_limit(%{headers: headers})
    Logger.warning("Shopify rate limit hit for #{url}, retrying...")

    case Map.get(headers, "retry-after") || Map.get(headers, "Retry-After") do
      [delay | _] when is_binary(delay) ->
        :timer.sleep(String.to_integer(delay) * 1000)

      _ ->
        :timer.sleep(1_000)
    end

    do_request(method, url, opts, retries - 1)
  end

  defp handle_response({:ok, %{status: 401}}, _method, _url, _opts, _retries) do
    {:error, :invalid_token}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _method, _url, _opts, _retries) do
    message =
      case body do
        %{"errors" => errors} -> errors
        %{"error" => error} -> error
        %{"message" => message} -> message
        other -> other
      end

    {:error, {status, message}}
  end

  defp handle_response({:error, reason}, _method, _url, _opts, _retries) do
    {:error, reason}
  end

  defp log_rate_limit(%{headers: headers}) do
    case Map.get(headers, "shopify-shop-api-call-limit") do
      [limit | _] when is_binary(limit) ->
        Logger.debug("Shopify rate limit: #{limit}")

      _ ->
        :ok
    end
  end

  defp log_rate_limit(_response), do: :ok

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end