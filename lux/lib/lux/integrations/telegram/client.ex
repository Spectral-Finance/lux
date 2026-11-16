defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  High-resilience HTTP client for Telegram Bot API requests.

  Features:
  - Automatic retry mechanism with backoff for transient network errors and rate limits (429)
  - Seamless rate-limit parameter extraction (`retry_after`)
  - Configurable mock plug support for 100% offline unit testing
  - Secure token resolution hierarchy (options -> Lux.Config -> System environment)
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"
  @default_max_retries 3

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()},
          optional(:retry) => boolean(),
          optional(:max_retries) => non_neg_integer()
        }

  @doc """
  Makes a request to the Telegram Bot API with retry and rate-limit handling.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/sendMessage")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Telegram Bot API token (required if not in config)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests
    * `:retry` - Boolean enabling/disabling automatic retries (default: true)
    * `:max_retries` - Maximum retry attempts on 429/5xx (default: 3)
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = resolve_token(opts[:token])
    url = @endpoint <> token <> path
    max_retries = Map.get(opts, :max_retries, @default_max_retries)

    req_options =
      [
        method: method,
        url: url,
        headers: [{"Content-Type", "application/json"} | Map.get(opts, :headers, [])],
        json: opts[:json],
        retry: if(Map.get(opts, :retry, true), do: :safe_transient, else: false),
        max_retries: max_retries
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])

    req_options
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    case response.body do
      %{"ok" => true} = body -> {:ok, body}
      body -> {:error, body}
    end
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :invalid_token}
  end

  defp handle_response(
         {:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => seconds}} = body}}
       ) do
    Logger.warning("Telegram Bot API rate limit reached. Retry after #{seconds} seconds.")
    {:error, {:rate_limited, seconds, body}}
  end

  defp handle_response({:ok, %{status: 429, body: body}}) do
    {:error, {:rate_limited, body}}
  end

  defp handle_response({:ok, %{status: status, body: %{"description" => message}}}) do
    {:error, {status, message}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp resolve_token(provided_token) when is_binary(provided_token) and provided_token != "",
    do: provided_token

  defp resolve_token(_) do
    try do
      Lux.Config.telegram_bot_token()
    rescue
      _ -> System.get_env("TELEGRAM_BOT_TOKEN") || ""
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
