defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  HTTP client for Telegram Bot API requests.
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"
  @retryable_statuses [429, 500, 502, 503, 504]

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:max_retries) => non_neg_integer(),
          optional(:retry_delay_ms) => non_neg_integer(),
          optional(:queue_interval_ms) => non_neg_integer(),
          optional(:plug) => {module(), term()}
        }

  @type queued_request :: %{
          required(:method) => atom(),
          required(:path) => String.t(),
          optional(:json) => map(),
          optional(:opts) => request_opts()
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
    * `:max_retries` - Number of retries for 429 and 5xx responses
    * `:retry_delay_ms` - Delay between retries, defaults to 250ms
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
    with {:ok, token} <- bot_token(opts) do
      max_retries = option(opts, :max_retries, 0)
      do_request(method, path, token, opts, max_retries, 0)
    end
  end

  @doc """
  Runs Telegram requests serially with an optional interval between items.

  This is intentionally process-free so callers can use it inside jobs, prisms,
  or their own supervision tree without starting a global queue.
  """
  @spec request_many([queued_request()], request_opts()) ::
          {:ok, [map()]}
          | {:error, %{failed_at: non_neg_integer(), reason: term(), completed: [map()]}}
  def request_many(requests, opts \\ []) when is_list(requests) do
    opts = opts_map(opts)
    interval_ms = Map.get(opts, :queue_interval_ms, 0)
    base_opts = Map.drop(opts, [:queue_interval_ms])

    requests
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {queued, index}, {:ok, completed} ->
      if index > 0, do: sleep(interval_ms)

      method = request_option(queued, :method, :post)
      path = request_option(queued, :path)
      request_opts = Map.merge(base_opts, opts_map(request_option(queued, :opts, %{})))
      request_opts = put_if_present(request_opts, :json, request_option(queued, :json))

      case request(method, path, request_opts) do
        {:ok, response} ->
          {:cont, {:ok, [response | completed]}}

        {:error, reason} ->
          {:halt,
           {:error, %{failed_at: index, reason: reason, completed: Enum.reverse(completed)}}}
      end
    end)
    |> case do
      {:ok, completed} -> {:ok, Enum.reverse(completed)}
      error -> error
    end
  end

  @doc "Returns bot identity for the configured token."
  @spec get_me(request_opts()) :: {:ok, map()} | {:error, term()}
  def get_me(opts \\ %{}), do: request(:get, "/getMe", opts)

  @doc "Sends a text message through Telegram Bot API."
  @spec send_message(String.t() | integer(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def send_message(chat_id, text, opts \\ %{}) do
    request(:post, "/sendMessage", put_json(opts, %{chat_id: chat_id, text: text}))
  end

  @doc "Edits a text message through Telegram Bot API."
  @spec edit_message_text(String.t() | integer(), integer(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def edit_message_text(chat_id, message_id, text, opts \\ %{}) do
    request(
      :post,
      "/editMessageText",
      put_json(opts, %{chat_id: chat_id, message_id: message_id, text: text})
    )
  end

  @doc "Deletes a message through Telegram Bot API."
  @spec delete_message(String.t() | integer(), integer(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def delete_message(chat_id, message_id, opts \\ %{}) do
    request(:post, "/deleteMessage", put_json(opts, %{chat_id: chat_id, message_id: message_id}))
  end

  defp do_request(method, path, token, opts, max_retries, attempt) do
    result = request_once(method, path, token, opts)

    case result do
      {:error, reason} when attempt < max_retries ->
        if retryable?(reason) do
          reason
          |> retry_delay_ms(opts, attempt)
          |> sleep()

          do_request(method, path, token, opts, max_retries, attempt + 1)
        else
          result
        end

      _ ->
        result
    end
  end

  defp request_once(method, path, token, opts) do
    [
      method: method,
      url: @endpoint <> token <> normalize_path(path),
      headers: [{"Content-Type", "application/json"}] ++ option(opts, :headers, []),
      json: option(opts, :json)
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(option(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  defp normalize_response({:ok, %{status: status, body: %{"ok" => true} = body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp normalize_response({:ok, %{status: status, body: %{"ok" => false} = body}}) do
    {:error, telegram_error(status, body)}
  end

  defp normalize_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:error, body}
  end

  defp normalize_response({:ok, %{status: 401}}), do: {:error, :invalid_token}

  defp normalize_response({:ok, %{status: status, body: body}})
       when status in @retryable_statuses do
    {:error, telegram_error(status, body)}
  end

  defp normalize_response({:ok, %{status: status, body: %{"description" => message}}}) do
    {:error, {status, message}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp telegram_error(401, _body), do: :invalid_token

  defp telegram_error(status, %{
         "parameters" => %{"retry_after" => retry_after},
         "description" => message
       })
       when status == 429 do
    {:rate_limited, retry_after, message}
  end

  defp telegram_error(status, %{"description" => message}) when status in @retryable_statuses do
    {status, message}
  end

  defp telegram_error(status, %{"description" => message}), do: {status, message}
  defp telegram_error(status, body), do: {status, body}

  defp retryable?({:rate_limited, _retry_after, _message}), do: true
  defp retryable?({status, _message}) when status in @retryable_statuses, do: true
  defp retryable?(_reason), do: false

  defp retry_delay_ms({:rate_limited, retry_after, _message}, opts, attempt) do
    if option(opts, :retry_delay_ms) == 0 do
      0
    else
      retry_after
      |> seconds_to_ms()
      |> min(option(opts, :max_retry_delay_ms, 30_000))
      |> max(backoff_ms(opts, attempt))
    end
  end

  defp retry_delay_ms(_reason, opts, attempt), do: backoff_ms(opts, attempt)

  defp backoff_ms(opts, attempt) do
    opts
    |> option(:retry_delay_ms, 250)
    |> Kernel.*(:math.pow(2, attempt))
    |> round()
  end

  defp seconds_to_ms(value) when is_integer(value), do: value * 1000
  defp seconds_to_ms(value) when is_float(value), do: round(value * 1000)

  defp seconds_to_ms(value) when is_binary(value),
    do: value |> String.to_integer() |> seconds_to_ms()

  defp bot_token(opts) do
    token = option(opts, :token) || configured_token()

    case token do
      token when is_binary(token) ->
        case String.trim(token) do
          "" -> {:error, :missing_token}
          trimmed -> {:ok, trimmed}
        end

      _ ->
        {:error, :missing_token}
    end
  end

  defp configured_token do
    Lux.Config.telegram_bot_token()
  rescue
    _error -> nil
  end

  defp normalize_path("/" <> _ = path), do: path
  defp normalize_path(path), do: "/" <> path

  defp put_json(opts, json) do
    opts
    |> opts_map()
    |> Map.update(:json, json, &Map.merge(json, &1))
  end

  defp put_if_present(opts, _key, nil), do: opts
  defp put_if_present(opts, key, value), do: Map.put(opts, key, value)

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp option(opts, key, default \\ nil)
  defp option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp request_option(opts, key, default \\ nil)
  defp request_option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp request_option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp sleep(ms) when is_integer(ms) and ms > 0, do: Process.sleep(ms)
  defp sleep(_ms), do: :ok

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
