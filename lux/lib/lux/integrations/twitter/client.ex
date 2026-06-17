defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter/X API v2 requests.

  Supports:
  - Bearer token authentication (app-only)
  - OAuth 2.0 user context authentication
  - Rate limit handling with automatic retry
  - Media upload via chunked upload API
  - Request/response logging

  ## Configuration

      config :lux, :api_keys,
        twitter_bearer_token: "YOUR_BEARER_TOKEN"

  ## Usage

      # Simple request
      Client.request(:get, "/tweets/1234567890")

      # With options
      Client.request(:get, "/tweets/search/recent", %{
        params: %{query: "elixir"}
      })

      # POST with body
      Client.request(:post, "/tweets", %{
        json: %{text: "Hello from Lux!"}
      })
  """

  require Logger

  @endpoint "https://api.twitter.com/2"
  @upload_endpoint "https://upload.twitter.com/1.1"
  @default_retry_after 60

  @type request_opts :: %{
    optional(:bearer_token) => String.t(),
    optional(:params) => map(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()},
    optional(:max_retries) => non_neg_integer()
  }

  @doc """
  Makes a request to the Twitter API v2.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete, :patch)
    * `path` - API endpoint path (e.g. "/tweets/123")
    * `opts` - Request options

  ## Options

    * `:bearer_token` - Twitter Bearer token (defaults to config)
    * `:params` - Query parameters for GET requests
    * `:json` - Request body for POST/PUT/PATCH requests
    * `:headers` - Additional headers
    * `:plug` - A plug for testing
    * `:max_retries` - Maximum retry attempts for rate limits (default: 3)

  ## Examples

      iex> Client.request(:get, "/tweets/1234567890")
      {:ok, %{"data" => %{"id" => "1234567890", "text" => "..."}}}

      iex> Client.request(:post, "/tweets", %{json: %{text: "Hello!"}})
      {:ok, %{"data" => %{"id" => "9876543210", "text" => "Hello!"}}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:bearer_token] || Lux.Config.twitter_bearer_token()
    max_retries = opts[:max_retries] || 3

    build_request(method, path, token, opts)
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response(method, path, token, opts, max_retries)
  end

  @doc """
  Makes a multipart request to the Twitter API (for media uploads).

  ## Parameters

    * `path` - API endpoint path (e.g. "/media/upload")
    * `fields` - Form fields as a list of tuples
    * `opts` - Request options

  ## Examples

      iex> Client.multipart_request("/media/upload", [
      ...>   {"media", {:file, "/path/to/image.jpg"}}
      ...> ])
      {:ok, %{"media_id_string" => "1234567890"}}
  """
  @spec multipart_request(String.t(), list(), request_opts()) :: {:ok, map()} | {:error, term()}
  def multipart_request(path, fields, opts \\ %{}) do
    token = opts[:bearer_token] || Lux.Config.twitter_bearer_token()

    multipart =
      fields
      |> Enum.map(fn
        {name, {:file, file_path}} -> {name, File.stream!(file_path, [], 1024)}
        {name, value} -> {name, to_string(value)}
      end)

    [
      method: :post,
      url: "#{@upload_endpoint}#{path}",
      headers: [
        {"Authorization", "Bearer #{token}"}
      ],
      multipart: multipart
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 429} = response} ->
        retry_after = get_rate_limit_reset(response) || @default_retry_after
        Logger.warning("Twitter rate limited on media upload. Retry after #{retry_after}s")
        {:error, {:rate_limited, retry_after}}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitter media upload failed: #{status} - #{inspect(body)}")
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns the current rate limit status for the given endpoint.
  """
  @spec rate_limit_status(String.t()) :: {:ok, map()} | {:error, term()}
  def rate_limit_status(endpoint) do
    request(:get, "/rate_limit_status", %{params: %{resources: endpoint}})
  end

  defp build_request(method, path, token, opts) do
    url = "#{@endpoint}#{path}"

    headers =
      [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
        | opts[:headers] || []
      ]

    base =
      [
        method: method,
        url: url,
        headers: headers
      ]

    case method do
      :get ->
        Keyword.put(base, :params, opts[:params] || %{})

      _ ->
        json = opts[:json] || %{}
        if opts[:params] do
          base
          |> Keyword.put(:json, json)
          |> Keyword.put(:params, opts[:params])
        else
          Keyword.put(base, :json, json)
        end
    end
  end

  defp handle_response({:ok, %{status: status} = response}, method, path, token, opts, retries)
       when status in 200..299 do
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: 401}}, _method, _path, _token, _opts, _retries) do
    {:error, :invalid_token}
  end

  defp handle_response({:ok, %{status: 429} = response}, method, path, token, opts, retries)
       when retries > 0 do
    retry_after = get_rate_limit_reset(response) || @default_retry_after
    Logger.warning("Twitter rate limited on #{method} #{path}. Retry after #{retry_after}s (#{retries} retries left)")
    Process.sleep(min(retry_after * 1000, 30_000))
    request(method, path, Map.put(opts, :max_retries, retries - 1))
  end

  defp handle_response({:ok, %{status: 429} = response}, _method, path, _token, _opts, 0) do
    retry_after = get_rate_limit_reset(response) || @default_retry_after
    Logger.error("Twitter rate limit exhausted for #{path}")
    {:error, {:rate_limited, retry_after}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _method, path, _token, _opts, _retries) do
    error_msg = extract_error_message(body)
    Logger.error("Twitter API error on #{path}: #{status} - #{error_msg}")
    {:error, {status, error_msg}}
  end

  defp handle_response({:error, error}, _method, _path, _token, _opts, _retries) do
    {:error, error}
  end

  defp get_rate_limit_reset(response) do
    case get_in(response.headers, ["x-rate-limit-reset"]) do
      [reset_time] when is_binary(reset_time) ->
        try do
          reset_unix = String.to_integer(reset_time)
          max(reset_unix - System.system_time(:second), 1)
        rescue
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_error_message(%{"errors" => errors}) when is_list(errors) do
    errors
    |> Enum.map(fn
      %{"message" => msg} -> msg
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp extract_error_message(%{"error" => error}) when is_binary(error), do: error
  defp extract_error_message(%{"detail" => detail}) when is_binary(detail), do: detail
  defp extract_error_message(%{"title" => title}) when is_binary(title), do: title
  defp extract_error_message(body) when is_map(body), do: Jason.encode!(body)
  defp extract_error_message(body), do: inspect(body)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
