defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Unified integration entrypoint for Twitter (X) API v2 and media upload endpoints.

  Provides high-level helpers for:
  - Request settings and authentication headers for Lux Lenses
  - OAuth 2.0 PKCE authentication flow and token refresh
  - Tweet lifecycle: create, delete, get, and thread chaining
  - User profiles: lookup by username, ID, and authenticated `/me`
  - Media uploads: simple (image/gif) and chunked (video)
  - Rate limit tracking and exponential backoff
  """

  alias Lux.Integrations.Twitter.{
    Client,
    Media,
    OAuth,
    RateLimiter,
    Tweets,
    Users
  }

  @doc """
  Default HTTP headers for Twitter API calls.
  """
  def headers do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "Lux-Agent-Framework/1.0"}
    ]
  end

  @doc """
  Auth settings for Twitter API calls in Lux Lenses.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Injects Bearer token into Plug.Conn headers for lenses.
  """
  def add_auth_header(%Plug.Conn{} = conn) do
    token = get_bearer_token()

    if token && token != "" do
      Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
    else
      conn
    end
  end

  def add_auth_header(req) when is_map(req) do
    token = get_bearer_token()

    if token && token != "" do
      headers = Map.get(req, :headers, [])
      Map.put(req, :headers, [{"Authorization", "Bearer #{token}"} | headers])
    else
      req
    end
  end

  defp get_bearer_token do
    case Application.get_env(:lux, :api_keys) do
      nil -> System.get_env("TWITTER_BEARER_TOKEN") || ""
      keys -> Keyword.get(keys, :twitter_bearer_token, System.get_env("TWITTER_BEARER_TOKEN") || "")
    end
  end

  # --- Delegation to Submodules ---

  # Tweets
  defdelegate create_tweet(params, opts \\ %{}), to: Tweets
  defdelegate delete_tweet(tweet_id, opts \\ %{}), to: Tweets
  defdelegate get_tweet(tweet_id, opts \\ %{}), to: Tweets
  defdelegate create_thread(tweets, opts \\ %{}), to: Tweets

  # Users
  defdelegate get_me(opts \\ %{}), to: Users
  defdelegate get_user_by_username(username, opts \\ %{}), to: Users
  defdelegate get_user_by_id(user_id, opts \\ %{}), to: Users

  # Media
  defdelegate upload_media(binary_data, media_type \\ "image/jpeg", opts \\ %{}), to: Media, as: :upload_simple
  defdelegate chunked_init(total_bytes, media_type, category \\ nil, opts \\ %{}), to: Media
  defdelegate chunked_append(media_id, index, chunk, opts \\ %{}), to: Media
  defdelegate chunked_finalize(media_id, opts \\ %{}), to: Media

  # OAuth 2.0 PKCE
  defdelegate generate_pkce_challenge(), to: OAuth
  defdelegate authorization_url(client_id, redirect_uri, scopes \\ nil, state \\ nil, code_challenge), to: OAuth
  defdelegate exchange_code(client_id, client_secret, code, verifier, redirect_uri, opts \\ %{}), to: OAuth
  defdelegate refresh_token(client_id, client_secret, refresh_token_val, opts \\ %{}), to: OAuth
  defdelegate encrypt_token(token, passphrase), to: OAuth
  defdelegate decrypt_token(encoded, passphrase), to: OAuth

  # Rate Limiter
  defdelegate init_rate_limiter(), to: RateLimiter, as: :init_state
  defdelegate check_quota(state, endpoint), to: RateLimiter
  defdelegate update_rate_limits(state, endpoint, headers), to: RateLimiter, as: :update_from_headers
  defdelegate calculate_backoff(attempt, reset_at \\ nil), to: RateLimiter
end
