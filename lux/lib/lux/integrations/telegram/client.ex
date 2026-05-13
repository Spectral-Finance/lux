defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  HTTP client for Telegram Bot API requests.
  """

  require Logger

  alias Lux.Integrations.Telegram.RateLimit

  @endpoint "https://api.telegram.org/bot"

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()},
    optional(:max_retries) => non_neg_integer(),
    optional(:retry_base_delay_ms) => non_neg_integer(),
    optional(:sleep) => (non_neg_integer() -> any())
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
    * `:max_retries` - Retry attempts for rate limits and transient failures (defaults to 2)
    * `:retry_base_delay_ms` - Initial exponential backoff delay for transient failures (defaults to 500)
    * `:sleep` - Delay function, useful for tests (defaults to `Process.sleep/1`)

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
    request_with_retry(method, path, opts, 0)
  end

  defp request_with_retry(method, path, opts, attempt) do
    case do_request(method, path, opts) do
      {:ok, %{status: status} = response} ->
        if RateLimit.retryable_status?(status) and attempt < option(opts, :max_retries, 2) do
          delay_ms =
            RateLimit.retry_delay_ms(status, response.body, response.headers, attempt,
              base_delay_ms: option(opts, :retry_base_delay_ms, 500)
            )

          Logger.debug("Retrying Telegram API request after #{delay_ms}ms",
            status: status,
            attempt: attempt + 1
          )

          sleep(opts).(delay_ms)
          request_with_retry(method, path, opts, attempt + 1)
        else
          normalize_response({:ok, response})
        end

      {:error, error} when attempt < option(opts, :max_retries, 2) ->
        delay_ms =
          RateLimit.retry_delay_ms(:network_error, nil, [], attempt,
            base_delay_ms: option(opts, :retry_base_delay_ms, 500)
          )

        Logger.debug("Retrying Telegram API request after transport error",
          error: inspect(error),
          delay_ms: delay_ms,
          attempt: attempt + 1
        )

        sleep(opts).(delay_ms)
        request_with_retry(method, path, opts, attempt + 1)

      result ->
        normalize_response(result)
    end
  end

  defp do_request(method, path, opts) do
    token = opts[:token] || Lux.Config.telegram_bot_token()
    url = @endpoint <> token <> path

    [
      method: method,
      url: url,
      headers: [{"Content-Type", "application/json"}] ++ (opts[:headers] || []),
      json: opts[:json]
    ]
    |> Keyword.merge(req_config())
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
  end

  defp normalize_response(result) do
    case result do
      {:ok, %{status: status} = response} when status in 200..299 ->
        case response.body do
          %{"ok" => true} = body -> {:ok, body}
          body -> {:error, body}
        end

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: %{"description" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp req_config do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.drop([:max_retries, :retry_base_delay_ms, :sleep])
  end

  defp option(opts, key, default) do
    case opts[key] do
      nil -> Keyword.get(Application.get_env(:lux, __MODULE__, []), key, default)
      value -> value
    end
  end

  defp sleep(opts), do: option(opts, :sleep, &Process.sleep/1)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
