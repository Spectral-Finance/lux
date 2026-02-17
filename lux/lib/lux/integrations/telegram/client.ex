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
    import Lux.Config
    import Lux.Lenses
    url = @endpoint <> token <> path

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
          |> Req.request()
          |> handle_response()
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end

def handle_rate_limit_error(error) do
  case error do
    {:error, {429, _message}} ->
      Logger.warn("Rate limit exceeded. Retrying in 1 minute.")
      :timer.sleep(60_000)
      {:retry}

    _ ->
      {:error, error}
  end
end

def handle_request_error(error) do
  case error do
    {:error, {code, message}} when code >= 500 ->
      Logger.error("Server error: #{message}. Retrying in 1 minute.")
      :timer.sleep(60_000)
      {:retry}

    _ ->
      {:error, error}
  end
end
      :timer.sleep(300_000)
      {:retry}

    _ ->
      {:error, error}
  end
end