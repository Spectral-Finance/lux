defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  HTTP client for Telegram Bot API requests.
  """

  require Logger

  @endpoint "https://api.telegram.org"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the Telegram Bot API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/sendMessage")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram bot token (required)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      iex> Telegram.Client.request(:post, "/sendMessage", %{
      ...>   json: %{chat_id: "123", text: "Hello!"}
      ...> })
      {:ok, %{"message_id" => 42, "text" => "Hello!"}}

  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || Lux.Config.telegram_bot_token()

    [
      method: method,
      url: "#{@endpoint}/bot#{token}#{path}",
      headers: [
        {"Content-Type", "application/json"}
        | opts[:headers] || []
      ],
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

      {:ok, %{status: 429} = response} ->
        retry_after = get_in(response.body, ["parameters", "retry_after"]) || 30
        Logger.warning("Rate limited. Retry after #{retry_after}s")
        {:error, {:rate_limited, retry_after}}

      {:ok, %{status: status, body: %{"description" => description}}} ->
        {:error, {status, description}}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Makes a multipart request to the Telegram Bot API (for file uploads).

  ## Parameters

    * `path` - API endpoint path (e.g. "/sendPhoto")
    * `fields` - Form fields as a list of tuples
    * `opts` - Request options

  ## Examples

      iex> Telegram.Client.multipart_request("/sendPhoto", [
      ...>   {"chat_id", "123"},
      ...>   {"photo", {:file, "/path/to/photo.jpg"}}
      ...> ])
      {:ok, %{"message_id" => 42}}

  """
  @spec multipart_request(String.t(), list(), request_opts()) :: {:ok, map()} | {:error, term()}
  def multipart_request(path, fields, opts \\ %{}) do
    token = opts[:token] || Lux.Config.telegram_bot_token()

    multipart =
      fields
      |> Enum.map(fn
        {name, {:file, path}} -> {name, File.stream!(path, [], 1024)}
        {name, value} -> {name, to_string(value)}
      end)

    [
      method: :post,
      url: "#{@endpoint}/bot#{token}#{path}",
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
        retry_after = get_in(response.body, ["parameters", "retry_after"]) || 30
        Logger.warning("Rate limited. Retry after #{retry_after}s")
        {:error, {:rate_limited, retry_after}}

      {:ok, %{status: status, body: %{"description" => description}}} ->
        {:error, {status, description}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
