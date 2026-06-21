defmodule Lux.Integrations.YouTube.Client do
  @moduledoc """
  Basic HTTP client for YouTube Data API v3 requests.
  """

  require Logger

  @endpoint "https://www.googleapis.com/youtube/v3"

  @type request_opts :: %{
    optional(:api_key) => String.t(),
    optional(:access_token) => String.t(),
    optional(:json) => map(),
    optional(:params) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the YouTube Data API v3.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/videos", "/search")
    * `opts` - Request options (see Options section)

  ## Options

    * `:api_key` - YouTube Data API key (for public data access)
    * `:access_token` - OAuth2 access token (for authenticated actions)
    * `:json` - Request body for POST/PUT requests
    * `:params` - Query parameters
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Using an API key for read operations
      iex> YouTube.Client.request(:get, "/videos", %{
      ...>   api_key: "your_api_key",
      ...>   params: %{part: "snippet", id: "dQw4w9WgXcQ"}
      ...> })
      {:ok, %{"items" => [...]}}

      # Using an OAuth2 token for write operations
      iex> YouTube.Client.request(:post, "/liveBroadcasts", %{
      ...>   access_token: "your_oauth_token",
      ...>   params: %{part: "snippet,status"},
      ...>   json: %{snippet: %{title: "My Stream"}}
      ...> })
      {:ok, %{"id" => "abc123"}}

  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    api_key = opts[:api_key] || Lux.Config.youtube_api_key()
    access_token = opts[:access_token]

    headers = build_headers(access_token)
    params = Map.merge(opts[:params] || %{}, if(access_token, do: %{}, else: %{key: api_key}))

    [
      method: method,
      url: @endpoint <> path,
      headers: headers,
      params: params,
      json: opts[:json]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: 403, body: %{"error" => %{"message" => message}}}} ->
        {:error, {403, message}}

      {:ok, %{status: status, body: %{"error" => %{"message" => message}}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_headers(nil), do: [{"Content-Type", "application/json"}]
  defp build_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
