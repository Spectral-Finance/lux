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
    token = opts[:token] || Lux.Config.telegram_bot_token()

    if is_nil(token) or token == "" do
      {:error, :missing_token}
    else
      url = @endpoint <> token <> path

      req =
        [
          method: method,
          url: url,
          headers: [
            {"Content-Type", "application/json"}
          ],
          json: opts[:json]
        ]
        |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
        |> maybe_add_plug(opts[:plug])
        |> Req.new()
        |> Req.Request.append_error_steps(redact_token: &redact_token_step(&1, token))

      Lux.Integrations.Telegram.Queue.enqueue(fn ->
        req
        |> Req.request()
        |> case do
          {:ok, %{status: status} = response} when status in 200..299 ->
            case response.body do
              %{"ok" => true} = body -> {:ok, body}
              body -> {:error, body}
            end

          {:ok, %{status: 401}} ->
            {:error, :invalid_token}

          {:ok, %{status: 429, body: %{"parameters" => %{"retry_after" => retry_after}}}} ->
            {:error, {:rate_limited, retry_after}}

          {:ok, %{status: 429, body: %{"description" => desc}}} ->
            # Fallback if parameters.retry_after is missing
            {:error, {:rate_limited, desc}}

          {:ok, %{status: status, body: %{"description" => message}}} ->
            {:error, {status, message}}

          {:ok, %{status: status, body: body}} ->
            {:error, {status, body}}

          {:error, error} ->
            {:error, error}
        end
      end)
    end
  end

  defp redact_token_step({request, exception}, token) do
    if Exception.message(exception) =~ token do
      redacted_msg = String.replace(Exception.message(exception), token, "***")
      # We create a new generic exception with the redacted message
      {request, RuntimeError.exception(redacted_msg)}
    else
      {request, exception}
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
