defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 requests.
  Uses OAuth 2.0 Bearer Token authentication.
  """

  require Logger

  @endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
    optional(:bearer_token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the Twitter API v2.

  ## Parameters
    * `method` - HTTP method (:get, :post, :delete, :put)
    * `path` - API endpoint path (e.g. "/tweets")
    * `opts` - Request options

  ## Options
    * `:bearer_token` - Twitter Bearer Token (falls back to config)
    * `:json` - Request body for POST requests
    * `:params` - Query parameters for GET requests

  ## Examples

      iex> Twitter.Client.request(:get, "/users/me", %{})
      {:ok, %{"data" => %{"id" => "123", "username" => "aurora_ai"}}}

      iex> Twitter.Client.request(:post, "/tweets", %{json: %{text: "Hello!"}})
      {:ok, %{"data" => %{"id" => "456", "text" => "Hello!"}}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    bearer_token = opts[:bearer_token] || Lux.Config.twitter_bearer_token()

    req_options = [
      method: method,
      url: @endpoint <> path,
      retry: false,
      headers: [
        {"Authorization", "Bearer #{bearer_token}"},
        {"Content-Type", "application/json"}
      ]
    ]

    req_options =
      if opts[:json], do: Keyword.put(req_options, :json, opts[:json]), else: req_options

    req_options =
      if opts[:params], do: Keyword.put(req_options, :params, opts[:params]), else: req_options

    req_options =
      req_options
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))

    req_options =
      case opts[:plug] do
        nil -> req_options
        plug -> Keyword.put(req_options, :plug, plug)
      end

    req_options
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: %{"detail" => detail}}} ->
        {:error, {status, detail}}

      {:ok, %{status: status, body: %{"title" => title}}} ->
        {:error, {status, title}}

      {:ok, %{status: status}} ->
        {:error, {status, "Unknown error"}}

      {:error, error} ->
        {:error, error}
    end
  end
end
