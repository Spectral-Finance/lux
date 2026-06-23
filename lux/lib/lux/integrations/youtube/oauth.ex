defmodule Lux.Integrations.YouTube.OAuth do
  @moduledoc """
  OAuth2 token management for YouTube integration.
  """

  require Logger

  defmodule TokenCache do
    @moduledoc """
    Simple Agent-based cache for storing OAuth tokens in-memory.
    """
    use Agent

    def start_link(initial_token_info \\ %{}) do
      Agent.start_link(fn -> initial_token_info end, name: __MODULE__)
    end

    def get_token do
      Agent.get(__MODULE__, & &1)
    end

    def put_token(token_info) do
      Agent.update(__MODULE__, fn _ -> token_info end)
    end
  end

  @doc """
  Generates the Google OAuth2 authorization URL.
  """
  def authorization_url(opts \\ []) do
    client_id = opts[:client_id] || System.get_env("YOUTUBE_CLIENT_ID") || Application.get_env(:lux, :youtube_client_id, "mock_client_id")
    redirect_uri = opts[:redirect_uri] || System.get_env("YOUTUBE_REDIRECT_URI") || Application.get_env(:lux, :youtube_redirect_uri, "mock_redirect_uri")
    scope = opts[:scope] || "https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/youtube"
    state = opts[:state] || ""

    query = URI.encode_query(%{
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: scope,
      state: state,
      access_type: "offline",
      prompt: "consent"
    })

    "https://accounts.google.com/o/oauth2/v2/auth?" <> query
  end

  @doc """
  Exchanges an authorization code for access and refresh tokens.
  """
  def exchange_code(code, opts \\ []) do
    client_id = opts[:client_id] || System.get_env("YOUTUBE_CLIENT_ID") || Application.get_env(:lux, :youtube_client_id, "mock_client_id")
    client_secret = opts[:client_secret] || System.get_env("YOUTUBE_CLIENT_SECRET") || Application.get_env(:lux, :youtube_client_secret, "mock_client_secret")
    redirect_uri = opts[:redirect_uri] || System.get_env("YOUTUBE_REDIRECT_URI") || Application.get_env(:lux, :youtube_redirect_uri, "mock_redirect_uri")
    plug = opts[:plug]

    [
      method: :post,
      url: "https://oauth2.googleapis.com/token",
      headers: [{"content-type", "application/x-www-form-urlencoded"}],
      form: [
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        code: code,
        grant_type: "authorization_code"
      ]
    ]
    |> maybe_add_plug(plug)
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        expires_in = body["expires_in"] || 3600
        expires_at = System.system_time(:second) + expires_in
        token_info = %{
          access_token: body["access_token"],
          refresh_token: body["refresh_token"],
          expires_in: expires_in,
          expires_at: expires_at
        }
        if hook = opts[:on_token_refreshed], do: hook.(token_info)
        cache_token(token_info)
        {:ok, token_info}

      {:ok, response} ->
        {:error, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refreshes an access token using a refresh token.
  """
  def refresh_token(refresh_token, opts \\ []) do
    client_id = opts[:client_id] || System.get_env("YOUTUBE_CLIENT_ID") || Application.get_env(:lux, :youtube_client_id, "mock_client_id")
    client_secret = opts[:client_secret] || System.get_env("YOUTUBE_CLIENT_SECRET") || Application.get_env(:lux, :youtube_client_secret, "mock_client_secret")
    plug = opts[:plug]

    [
      method: :post,
      url: "https://oauth2.googleapis.com/token",
      headers: [{"content-type", "application/x-www-form-urlencoded"}],
      form: [
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      ]
    ]
    |> maybe_add_plug(plug)
    |> Req.request()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        expires_in = body["expires_in"] || 3600
        expires_at = System.system_time(:second) + expires_in
        new_token_info = %{
          access_token: body["access_token"],
          refresh_token: body["refresh_token"] || refresh_token,
          expires_in: expires_in,
          expires_at: expires_at
        }
        if hook = opts[:on_token_refreshed], do: hook.(new_token_info)
        cache_token(new_token_info)
        {:ok, new_token_info}

      {:ok, response} ->
        {:error, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if the token has expired or is about to expire.
  """
  def expired?(token_info, buffer_seconds \\ 60) do
    case token_info[:expires_at] do
      nil -> true
      expires_at ->
        current_time = System.system_time(:second)
        current_time + buffer_seconds >= expires_at
    end
  end

  def token_expired?(token_info), do: expired?(token_info)

  @doc """
  Gets a valid access token. Checks cache first, and if expired/missing,
  refreshes it using the refresh token if available.
  """
  def get_valid_token(opts \\ []) do
    token_info = get_cached_token()

    cond do
      token_info && not expired?(token_info) ->
        {:ok, token_info.access_token}

      token_info && token_info[:refresh_token] ->
        case refresh_token(token_info.refresh_token, opts) do
          {:ok, new_info} -> {:ok, new_info.access_token}
          {:error, reason} -> {:error, reason}
        end

      true ->
        {:error, :no_token_available}
    end
  end

  # --- Cache Helpers ---

  def get_cached_token do
    if Process.whereis(TokenCache) do
      TokenCache.get_token()
    else
      nil
    end
  end

  def cache_token(token_info) do
    if Process.whereis(TokenCache) do
      TokenCache.put_token(token_info)
    else
      :ok
    end
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
