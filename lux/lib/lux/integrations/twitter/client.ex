defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 requests with OAuth 2.0 Bearer token authentication.

  Supports:
  - Tweet creation, retrieval, deletion, editing
  - Quote tweets and thread creation
  - Media upload (images, videos, GIFs)
  - User profile management
  - Rate limit handling with automatic retry

  ## Authentication

  Uses OAuth 2.0 Bearer token authentication. The token is retrieved from
  `Lux.Config.twitter_bearer_token/0` or passed via `:token` option.

  ## Rate Limit Handling

  Twitter API enforces rate limits. This client automatically detects
  429 responses and retries after the specified delay.

  ## Examples

      # Create a tweet
      iex> Client.request(:post, "/tweets", %{json: %{text: "Hello World!"}})
      {:ok, %{"data" => %{"id" => "123456789", "text" => "Hello World!"}}}

      # Get user me
      iex> Client.request(:get, "/users/me")
      {:ok, %{"data" => %{"id" => "123", "name" => "My Account"}}}

      # Upload media
      iex> Client.request(:post, "/1.1/media/upload.json", %{
      ...>   json: %{media: base64_encoded_image}
      ...> })
      {:ok, %{"media_id_string" => "abc123"}}
  """

  require Logger

  @base_url "https://api.twitter.com/2"
  @upload_url "https://upload.twitter.com/1.1"
  @auth_url "https://api.twitter.com/2/oauth2"
  @max_retries 3

  @typedoc """
  Request options for Twitter API calls.
  """
  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()},
    optional(:retry_count) => non_neg_integer()
  }

  @doc """
  Makes a request to the Twitter API v2.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete, :patch)
    * `path` - API endpoint path (e.g. "/tweets", "/users/me")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Bearer token (falls back to config)
    * `:json` - JSON request body for POST/PUT/PATCH
    * `:params` - Query parameters for GET requests
    * `:headers` - Additional headers
    * `:plug` - Test plug for mocking
    * `:retry_count` - Internal: current retry count (start at 0)

  ## Rate Limit Handling

  On 429 responses, the client retries up to `@max_retries` times,
  waiting the duration specified in the `Retry-After` header.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    opts = Map.put_new(opts, :retry_count, 0)
    token = opts[:token] || Lux.Config.twitter_bearer_token()
    url = build_url(path)

    headers =
      [{"Authorization", "Bearer #{token}"}]
      |> maybe_append_extra_headers(opts[:headers])

    req_opts = [
      method: method,
      url: url,
      headers: headers,
      max_retries: @max_retries
    ]
    |> maybe_put(:json, opts[:json])
    |> maybe_put(:params, opts[:params])
    |> maybe_add_plug(opts[:plug])

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_response(opts[:retry_count] || 0)
  end

  @doc """
  Uploads media (image, video, GIF) to Twitter.

  Returns {:ok, %{media_id: media_id_string}} on success.
  """
  @spec upload_media(String.t(), binary(), String.t()) :: {:ok, map()} | {:error, term()}
  def upload_media(media_data, media_type \\ "image/png", opts \\ %{}) do
    token = opts[:token] || Lux.Config.twitter_bearer_token()

    url = "#{@upload_url}/media/upload.json"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", media_type}
    ]

    req_opts = [
      method: :post,
      url: url,
      headers: headers,
      body: media_data
    ]
    |> maybe_add_plug(opts[:plug])

    req_opts
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Performs an OAuth 2.0 client credentials token exchange.

  Uses API key/secret to obtain a bearer token.
  """
  @spec oauth_client_credentials(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def oauth_client_credentials(api_key, api_secret) do
    url = "#{@auth_url}/token"

    credentials = Base.encode64("#{api_key}:#{api_secret}")

    Req.new()
    |> Req.Request.append_headers([{"Authorization", "Basic #{credentials}"}])
    |> Req.Post(url: url, form: [grant_type: "client_credentials"])
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Refreshes an OAuth 2.0 bearer token using refresh token flow.
  """
  @spec oauth_refresh_token(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def oauth_refresh_token(refresh_token, api_key) do
    url = "#{@auth_url}/oauth2/token"

    credentials = Base.encode64("#{api_key}:")

    Req.new()
    |> Req.Request.append_headers([
      {"Authorization", "Basic #{credentials}"},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ])
    |> Req.Post(url: url, form: [grant_type: "refresh_token", refresh_token: refresh_token])
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  # --- Private helpers ---

  defp build_url("/1.1" <> _ = path), do: @upload_url <> path
  defp build_url(path), do: @base_url <> path

  defp maybe_append_extra_headers(headers, nil), do: headers
  defp maybe_append_extra_headers(headers, extra), do: headers ++ extra

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, response}, retry_count) do
    status = response.status

    cond do
      status == 429 and retry_count < @max_retries ->
        retry_after = parse_retry_after(response)
        Logger.warning("Twitter API rate limited (429), retrying in #{retry_after}ms (attempt #{retry_count + 1})")
        Process.sleep(retry_after)
        handle_response(request_from_last_opts(), retry_count + 1)

      status in 200..299 ->
        {:ok, response.body}

      true ->
        {:error, {status, response.body}}
    end
  end

  defp handle_response({:error, error}, _retry_count) do
    {:error, error}
  end

  defp parse_retry_after(response) do
    case response.headers do
      [{"retry-after", seconds}] -> String.to_integer(seconds) * 1000
      _ -> 1000 * (response.status - 200)
    end
  end
end
