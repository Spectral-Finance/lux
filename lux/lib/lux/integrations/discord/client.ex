defmodule Lux.Integrations.Discord.Client do
  @moduledoc """
  Basic HTTP client for Discord API requests.
  """

  require Logger

  @endpoint "https://discord.com/api/v10"

  @type token_type :: :bot | :bearer
  @type request_opts :: %{
    optional(:token) => String.t(),
    optional(:token_type) => token_type(),
    optional(:json) => map(),
    optional(:headers) => [{String.t(), String.t()}],
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the Discord API.

  ## Parameters

    * `method` - HTTP method (:get, :post, :put, :delete)
    * `path` - API endpoint path (e.g. "/channels/123")
    * `opts` - Request options (see Options section)

  ## Options

    * `:token` - Discord API key (required)
    * `:token_type` - Type of token, either `:bot` or `:bearer` (defaults to `:bot`)
    * `:json` - Request body for POST/PUT requests
    * `:headers` - Additional headers to include
    * `:plug` - A plug to use for testing instead of making real HTTP requests

  ## Examples

      # Using a bot token (default)
      iex> Discord.Client.request(:get, "/users/@me", %{token: "your_api_key"})
      {:ok, %{"id" => "123", "username" => "bot"}}

      # Using a bearer token (OAuth2)
      iex> Discord.Client.request(:post, "/channels/123/messages", %{
      ...>   token: "your_api_key",
      ...>   token_type: :bearer,
      ...>   json: %{content: "Hello!"}
      ...> })
      {:ok, %{"id" => "456", "content" => "Hello!"}}

  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    token = opts[:token] || Lux.Config.discord_api_key()
    token_type = opts[:token_type] || :bot

    [
      method: method,
      url: @endpoint <> path,
      headers: [
        {"Authorization", build_auth_header(token, token_type)},
        {"Content-Type", "application/json"}
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

      {:ok, %{status: status, body: %{"message" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_auth_header(token, token_type) do
    case token_type do
      :bot -> "Bot #{token}"
      :bearer -> "Bearer #{token}"
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
