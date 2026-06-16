defmodule Lux.Integrations.Telegram.Client do
  @moduledoc """
  Hardened HTTP client for Telegram Bot API requests.

  Provides:
  - Token retrieval with fallback (Application env → system env → `{:error, :missing_token}`)
  - Automatic exponential backoff retries for transient errors (500, 502, 503, 504)
    and transport errors
  - Rate limit handling for HTTP 429 with `retry_after` extraction
  - Serial queued request execution via `request_many/2`
  - Multipart file uploads with `File.stream!` via `multipart_request/4`
  """

  require Logger

  @endpoint "https://api.telegram.org/bot"
  @default_max_retries 3

  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()},
    optional(:max_retries) => non_neg_integer()
  }

  @doc """
  Makes a request to the Telegram Bot API with automatic retries and exponential backoff.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/sendMessage")
    * `opts` - Request options map

  ## Options

    * `:token` - Telegram Bot API token (overrides config/env lookup)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests
    * `:max_retries` - Maximum number of retries (default: #{@default_max_retries})

  ## Return Values

    * `{:ok, body}` — on successful API response with `"ok" => true`
    * `{:error, :missing_token}` — when no token is available
    * `{:error, :invalid_token}` — on HTTP 401
    * `{:error, %{reason: :rate_limited, retry_after: seconds, description: msg}}` — on 429 after retries exhausted
    * `{:error, {status, message}}` — on other API errors
    * `{:error, term()}` — on transport/network errors

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
    case fetch_token(opts) do
      {:ok, token} ->
        url = @endpoint <> token <> path

        req_opts =
          [
            method: method,
            url: url,
            headers: opts[:headers] || [{"Content-Type", "application/json"}],
            json: opts[:json],
            retry: false
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
          |> maybe_add_plug(opts[:plug])

        req = Req.new(req_opts)
        max_retries = opts[:max_retries] || get_config_max_retries()

        execute_with_retry(req, max_retries, 0)

      {:error, :missing_token} = err ->
        err
    end
  end

  @doc """
  Executes a list of requests sequentially (serial queue).

  If any request fails, execution is halted immediately and the error is returned.
  Successful results are accumulated in order and returned as `{:ok, [result1, result2, ...]}`.

  ## Parameters

    * `requests` - A list of requests to execute. Each request can be:
      - `{method, path}` — tuple with HTTP method and path
      - `{method, path, opts}` — tuple with method, path, and options map
      - `%{method: method, path: path}` — map with method and path
      - `%{method: method, path: path, opts: opts}` — map with opts
    * `opts` - Common/default request options merged into each individual request.
      Supports `:delay` key (milliseconds) to pause between requests.

  ## Examples

      iex> Client.request_many([
      ...>   {:post, "/sendMessage", %{json: %{chat_id: 1, text: "Hello"}}},
      ...>   {:post, "/sendMessage", %{json: %{chat_id: 1, text: "World"}}}
      ...> ], %{token: "bot_token"})
      {:ok, [%{"ok" => true, ...}, %{"ok" => true, ...}]}
  """
  @spec request_many(list(), map() | keyword()) :: {:ok, list(map())} | {:error, term()}
  def request_many(requests, opts \\ %{}) do
    common_opts = if is_list(opts), do: Map.new(opts), else: opts
    delay = Map.get(common_opts, :delay, 0)
    common_opts = Map.delete(common_opts, :delay)
    execute_serial(requests, common_opts, delay, [])
  end

  @doc """
  Performs a multipart file upload request using `File.stream!` for local files.

  File values in `params` can be specified as:
  - `{:file, filepath}` — explicit file marker tuple
  - A string path to an existing local file (auto-detected, must not be a URL)

  Non-file values are automatically stringified or JSON-encoded.

  ## Parameters

    * `method` - HTTP method (typically `:post`)
    * `path` - API endpoint path (e.g. "/sendPhoto")
    * `params` - Map of parameters, where file values trigger streaming upload
    * `opts` - Additional request options (same as `request/3`)

  ## Examples

      iex> Client.multipart_request(:post, "/sendPhoto", %{
      ...>   chat_id: "123456",
      ...>   photo: {:file, "/path/to/image.jpg"}
      ...> }, %{token: "bot_token"})
      {:ok, %{"ok" => true, ...}}
  """
  @spec multipart_request(atom(), String.t(), map(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def multipart_request(method, path, params, opts \\ %{}) do
    case fetch_token(opts) do
      {:ok, token} ->
        url = @endpoint <> token <> path
        form_multipart = build_form_multipart(params)

        req_opts =
          [
            method: method,
            url: url,
            form_multipart: form_multipart,
            retry: false
          ]
          |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
          |> maybe_add_plug(opts[:plug])

        req = Req.new(req_opts)
        max_retries = opts[:max_retries] || get_config_max_retries()

        execute_with_retry(req, max_retries, 0)

      {:error, :missing_token} = err ->
        err
    end
  end

  # --- Internal Helpers ---

  @doc false
  defp fetch_token(opts) do
    cond do
      is_binary(opts[:token]) and opts[:token] != "" ->
        {:ok, opts[:token]}

      true ->
        Lux.Integrations.Telegram.get_token()
    end
  end

  defp get_config_max_retries do
    Application.get_env(:lux, __MODULE__, [])
    |> Keyword.get(:max_retries, @default_max_retries)
  end

  # Core execution loop with backoff retry handling
  defp execute_with_retry(req, max_retries, attempt) do
    case Req.request(req) do
      {:ok, %{status: status} = response} when status in 200..299 ->
        case response.body do
          %{"ok" => true} = body -> {:ok, body}
          body -> {:error, body}
        end

      {:ok, %{status: 401}} ->
        {:error, :invalid_token}

      {:ok, %{status: 429} = response} ->
        retry_after = extract_retry_after(response)
        description = get_in(response.body, ["description"]) || "Too Many Requests"

        if attempt < max_retries do
          delay_seconds = retry_after || calculate_backoff_delay(attempt)

          Logger.warning(
            "Telegram API 429 rate limit. Retrying in #{delay_seconds}s " <>
              "(attempt #{attempt + 1}/#{max_retries}). #{description}"
          )

          Process.sleep(delay_seconds * 1000)
          execute_with_retry(req, max_retries, attempt + 1)
        else
          {:error,
           %{
             reason: :rate_limited,
             retry_after: retry_after || calculate_backoff_delay(attempt),
             description: description
           }}
        end

      {:ok, %{status: status} = response} when status in [500, 502, 503, 504] ->
        if attempt < max_retries do
          delay_seconds = calculate_backoff_delay(attempt)

          Logger.warning(
            "Telegram API #{status} transient error. Retrying in #{delay_seconds}s " <>
              "(attempt #{attempt + 1}/#{max_retries})."
          )

          Process.sleep(delay_seconds * 1000)
          execute_with_retry(req, max_retries, attempt + 1)
        else
          {:error, {status, response.body}}
        end

      {:ok, %{status: status, body: %{"description" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, %Req.TransportError{} = error} ->
        if attempt < max_retries do
          delay_seconds = calculate_backoff_delay(attempt)

          Logger.warning(
            "Telegram API transport error: #{inspect(error)}. Retrying in #{delay_seconds}s " <>
              "(attempt #{attempt + 1}/#{max_retries})."
          )

          Process.sleep(delay_seconds * 1000)
          execute_with_retry(req, max_retries, attempt + 1)
        else
          {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  # Extract rate-limiting delay from response body parameters or Retry-After header
  defp extract_retry_after(response) do
    body_retry_after = get_in(response.body, ["parameters", "retry_after"])

    header_retry_after =
      case Req.Response.get_header(response, "retry-after") do
        [value | _] ->
          case Integer.parse(value) do
            {sec, _} -> sec
            :error -> nil
          end

        _ ->
          nil
      end

    body_retry_after || header_retry_after
  end

  # Standard exponential backoff: 2^attempt (seconds), e.g. 1s, 2s, 4s, 8s
  defp calculate_backoff_delay(attempt) do
    :math.pow(2, attempt) |> round()
  end

  # Queue serialization logic
  defp execute_serial([], _common_opts, _delay, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp execute_serial([req | rest], common_opts, delay, acc) do
    {method, path, req_opts} = normalize_request(req)
    merged_opts = Map.merge(common_opts, req_opts)

    case request(method, path, merged_opts) do
      {:ok, result} ->
        if delay > 0 and rest != [], do: Process.sleep(delay)
        execute_serial(rest, common_opts, delay, [result | acc])

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Normalize different request representations
  defp normalize_request({method, path, req_opts})
       when is_atom(method) and is_binary(path) and is_map(req_opts) do
    {method, path, req_opts}
  end

  defp normalize_request({method, path, req_opts})
       when is_atom(method) and is_binary(path) and is_list(req_opts) do
    {method, path, Map.new(req_opts)}
  end

  defp normalize_request({method, path}) when is_atom(method) and is_binary(path) do
    {method, path, %{}}
  end

  defp normalize_request(%{method: method, path: path} = req)
       when is_atom(method) and is_binary(path) do
    req_opts = req[:opts] || %{}
    req_opts = if is_list(req_opts), do: Map.new(req_opts), else: req_opts

    # Move json root key to option map if needed
    req_opts =
      if Map.has_key?(req, :json) and not Map.has_key?(req_opts, :json) do
        Map.put(req_opts, :json, req.json)
      else
        req_opts
      end

    {method, path, req_opts}
  end

  # Construct the form_multipart representation
  defp build_form_multipart(params) do
    Enum.map(params, fn {key, value} ->
      key_str = to_string(key)

      cond do
        # Explicit file marker: {:file, filepath}
        is_tuple(value) and tuple_size(value) == 2 and elem(value, 0) == :file ->
          filepath = elem(value, 1)
          filename = Path.basename(filepath)
          {key_str, {File.stream!(filepath), filename: filename}}

        # File.Stream struct
        match?(%File.Stream{}, value) ->
          filename = Path.basename(value.path)
          {key_str, {value, filename: filename}}

        # String file path (auto-detect: not URL, file exists)
        is_binary(value) and not String.starts_with?(value, ["http://", "https://"]) and
            File.exists?(value) ->
          filename = Path.basename(value)
          {key_str, {File.stream!(value), filename: filename}}

        # Standard param — encode appropriately
        true ->
          encoded =
            cond do
              is_binary(value) -> value
              is_map(value) or is_list(value) -> Jason.encode!(value)
              true -> to_string(value)
            end

          {key_str, encoded}
      end
    end)
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
