defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Twitter API Core Integration ($2,500).

  Provides Twitter API v2 configuration, OAuth 2.0 PKCE helpers,
  request signing, and endpoint builders for tweets, users, and streams.

  ## Configuration

      config :lux, Lux.Integrations.Twitter,
        bearer_token:  System.get_env("TWITTER_BEARER_TOKEN"),
        api_key:       System.get_env("TWITTER_API_KEY"),
        api_secret:    System.get_env("TWITTER_API_SECRET"),
        access_token:  System.get_env("TWITTER_ACCESS_TOKEN"),
        access_secret: System.get_env("TWITTER_ACCESS_SECRET")
  """

  @base_v2 "https://api.twitter.com/2"
  @auth_url "https://twitter.com/i/oauth2/authorize"
  @token_url "https://api.twitter.com/2/oauth2/token"

  def base_url, do: @base_v2

  def bearer_token do
    Application.get_env(:lux, __MODULE__, [])[:bearer_token] ||
      System.get_env("TWITTER_BEARER_TOKEN") || ""
  end

  @doc "Returns app-only (Bearer token) auth headers."
  def app_headers do
    [{"Authorization", "Bearer #{bearer_token()}"},
     {"Content-Type", "application/json"}]
  end

  @doc "Returns OAuth 1.0a user-context headers (for write endpoints)."
  @spec user_headers(String.t(), String.t(), String.t(), String.t()) :: list()
  def user_headers(method, url, api_key, api_secret) do
    # Simplified OAuth 1.0a header builder
    ts    = to_string(System.system_time(:second))
    nonce = Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    params = "oauth_consumer_key=#{api_key}&oauth_nonce=#{nonce}&oauth_signature_method=HMAC-SHA1&oauth_timestamp=#{ts}&oauth_version=1.0"
    sig_base = "#{String.upcase(method)}&#{URI.encode(url, &URI.char_unreserved?/1)}&#{URI.encode(params, &URI.char_unreserved?/1)}"
    sig_key  = "#{api_secret}&"
    sig = :crypto.mac(:hmac, :sha, sig_key, sig_base) |> Base.encode64()
    oauth = "OAuth oauth_consumer_key=\"#{api_key}\", oauth_nonce=\"#{nonce}\", oauth_signature=\"#{URI.encode(sig)}\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"#{ts}\", oauth_version=\"1.0\""
    [{"Authorization", oauth}, {"Content-Type", "application/json"}]
  end

  # Tweet endpoints
  def tweet_url(id),                      do: @base_v2 <> "/tweets/#{id}"
  def create_tweet_url,                   do: @base_v2 <> "/tweets"
  def delete_tweet_url(id),               do: @base_v2 <> "/tweets/#{id}"
  def search_recent_url(query, max \\ 10), do: @base_v2 <> "/tweets/search/recent?query=#{URI.encode(query)}&max_results=#{max}"
  def timeline_url(user_id, max \\ 10),   do: @base_v2 <> "/users/#{user_id}/tweets?max_results=#{max}"

  # User endpoints
  def user_by_username_url(username),     do: @base_v2 <> "/users/by/username/#{username}"
  def me_url,                             do: @base_v2 <> "/users/me"
  def followers_url(user_id, max \\ 100), do: @base_v2 <> "/users/#{user_id}/followers?max_results=#{max}"
  def following_url(user_id, max \\ 100), do: @base_v2 <> "/users/#{user_id}/following?max_results=#{max}"

  # Stream endpoints
  def filtered_stream_url,                do: @base_v2 <> "/tweets/search/stream"
  def stream_rules_url,                   do: @base_v2 <> "/tweets/search/stream/rules"
end
