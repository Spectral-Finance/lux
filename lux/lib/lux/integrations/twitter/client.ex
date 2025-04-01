defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 requests.
  """

  require Logger
  alias Lux.Integrations.Twitter

  @endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()},
    optional(:form) => Keyword.t()
  }

  @doc """
  Makes a request to the Twitter API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/tweets")
    * `opts` - Request options (see Options section)

  ## Options

    * `:json` - Request body for POST/PUT requests as JSON
    * `:form` - Request body for POST/PUT requests as form data
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Post a tweet
      iex> Twitter.Client.request(:post, "/tweets", %{json: %{text: "Hello from Lux!"}})
      {:ok, %{"data" => %{"id" => "1234567890", "text" => "Hello from Lux!"}}}

  ## Authentication

  This client automatically handles OAuth token refreshing through the Twitter module.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    # For token refresh, we don't need a token to authenticate (we're getting one)
    if String.ends_with?(path, "/oauth2/token") do
      make_request_without_auth(method, path, opts)
    else
      case Twitter.get_access_token() do
        {:ok, token} ->
          make_request(method, path, token, opts)
        error ->
          error
      end
    end
  end

  # Makes a request without authentication (for getting tokens)
  defp make_request_without_auth(method, path, opts) do
    url = if String.starts_with?(path, "/oauth2") do
      "https://api.twitter.com/2" <> path
    else
      @endpoint <> path
    end

    [
      method: method,
      url: url,
      headers: opts[:headers] || [],
      json: opts[:json]
    ]
    |> add_form_data(opts[:form])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitter API error: #{status} - #{inspect(body)}")
        {:error, {status, body}}

      {:error, error} ->
        Logger.error("Twitter API request failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private function to make the actual request once we have a valid token
  defp make_request(method, path, token, opts) do
    [
      method: method,
      url: @endpoint <> path,
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ] ++ (opts[:headers] || []),
      json: opts[:json]
    ]
    |> add_form_data(opts[:form])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status} = response} when status in 200..299 ->
        {:ok, response.body}

      {:ok, %{status: 401}} ->
        # Token might be expired, force refresh and try again
        case Twitter.refresh_access_token() do
          {:ok, new_token} ->
            make_request(method, path, new_token, opts)
          error ->
            error
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitter API error: #{status} - #{inspect(body)}")
        {:error, {status, body}}

      {:error, error} ->
        Logger.error("Twitter API request failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Add form data if present
  defp add_form_data(options, nil), do: options
  defp add_form_data(options, form), do: Keyword.put(options, :form, form)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
