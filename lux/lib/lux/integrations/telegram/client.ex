defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  Basic HTTP client for Telegram Bot API requests.
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"

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
    * `path` - API endpoint path (e.g. "/copyMessage")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Send a message
      iex> Telegram.Client.request(:post, "/sendMessage", %{
      ...>   token: "your_bot_token",
      ...>   json: %{chat_id: 123_456_789, text: "Hello!"}
      ...> })
      {:ok, %{"ok" => true, "result" => %{"message_id" => 456}}}

      # Copy a message
      iex> Telegram.Client.request(:post, "/copyMessage", %{
      ...>   token: "your_bot_token",
      ...>   json: %{chat_id: 123_456_789, from_chat_id: 987_654_321, message_id: 42}
      ...> })
      {:ok, %{"ok" => true, "result" => %{"message_id" => 123}}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    opts_list = if is_map(opts), do: Map.to_list(opts), else: opts || []
    opts_map = Map.new(opts_list)

    token = opts_map[:token] || Lux.Config.telegram_bot_token()
    url = @endpoint <> to_string(token) <> path

    middleware_keys = [
      :sleep_fun,
      :max_retries,
      :max_rate_limit_retries,
      :base_backoff,
      :max_backoff,
      :backoff_factor
    ]

    app_env_opts = Keyword.drop(Application.get_env(:lux, __MODULE__, []), middleware_keys)

    headers = opts_map[:headers] || [{"Content-Type", "application/json"}]

    req_opts =
      [
        method: method,
        url: url,
        headers: headers,
        retry: false
      ]
      |> maybe_add_json(opts_map[:json])
      |> Keyword.merge(app_env_opts)
      |> maybe_add_plug(opts_map[:plug])

    middleware_opts =
      Application.get_env(:lux, __MODULE__, [])
      |> Keyword.merge(opts_list)

    try do
      req_opts
      |> Req.new()
      |> Lux.Telegram.Middleware.RateLimit.attach(middleware_opts)
      |> Lux.Telegram.Middleware.Retry.attach(middleware_opts)
      |> Req.request()
      |> case do
        {:ok, %{status: status} = response} when status in 200..299 ->
          case response.body do
            %{"ok" => true} = body -> {:ok, body}
            body -> {:error, body}
          end

        {:ok, %{status: 401}} ->
          {:error, :invalid_token}

        {:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => _}} = body}} ->
          {:error, {429, body}}

        {:ok, %{status: 429, body: %{parameters: %{retry_after: _}} = body}} ->
          {:error, {429, body}}

        {:ok, %{status: status, body: %{"description" => message}}} ->
          {:error, {status, message}}

        {:ok, %{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, error} ->
          {:error, error}
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Downloads a file from Telegram by file_path or file_id.
  """
  def download_file(file_path_or_id, opts \\ %{}) do
    Lux.Telegram.Media.download_file(file_path_or_id, opts)
  end

  @doc """
  Gets file info for a given file_id.
  """
  def get_file(file_id, opts \\ %{}) do
    Lux.Telegram.Media.get_file(file_id, opts)
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp maybe_add_json(options, nil), do: options
  defp maybe_add_json(options, json), do: Keyword.put(options, :json, json)
end
