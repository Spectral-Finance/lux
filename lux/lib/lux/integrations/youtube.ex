defmodule Lux.Integrations.YouTube do
  @moduledoc """
  YouTube Core Integration and Live Streaming ($3,000).

  Provides YouTube Data API v3 and Live Streaming API configuration,
  authentication helpers, quota tracking, and endpoint builders.

  ## Configuration

      config :lux, Lux.Integrations.YouTube,
        api_key:       System.get_env("YOUTUBE_API_KEY"),
        client_id:     System.get_env("YOUTUBE_CLIENT_ID"),
        client_secret: System.get_env("YOUTUBE_CLIENT_SECRET")
  """

  @base_url  "https://www.googleapis.com/youtube/v3"
  @live_url  "https://www.googleapis.com/youtube/v3"
  @auth_url  "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"

  @scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.readonly"
  ]

  def base_url,  do: @base_url
  def auth_url,  do: @auth_url
  def token_url, do: @token_url
  def scopes,    do: @scopes

  def api_key do
    Application.get_env(:lux, __MODULE__, [])[:api_key] ||
      System.get_env("YOUTUBE_API_KEY") || ""
  end

  def client_id do
    Application.get_env(:lux, __MODULE__, [])[:client_id] ||
      System.get_env("YOUTUBE_CLIENT_ID") ||
      raise ArgumentError, "YOUTUBE_CLIENT_ID not configured"
  end

  def headers(access_token) do
    [{"Authorization", "Bearer #{access_token}"},
     {"Content-Type", "application/json"},
     {"Accept", "application/json"}]
  end

  def api_headers, do: [{"Accept", "application/json"}]

  # Data API endpoints
  def videos_url(part \\ "snippet,statistics"),     do: @base_url <> "/videos?part=#{part}&key=#{api_key()}"
  def channels_url(part \\ "snippet,statistics"),   do: @base_url <> "/channels?part=#{part}&key=#{api_key()}"
  def search_url(query, max \\ 10),                 do: @base_url <> "/search?q=#{URI.encode(query)}&maxResults=#{max}&key=#{api_key()}"
  def playlists_url(channel_id),                    do: @base_url <> "/playlists?channelId=#{channel_id}&key=#{api_key()}"
  def comments_url(video_id, max \\ 20),            do: @base_url <> "/commentThreads?videoId=#{video_id}&maxResults=#{max}&key=#{api_key()}"

  # Live Streaming API endpoints
  def live_broadcasts_url(part \\ "snippet,status"), do: @live_url <> "/liveBroadcasts?part=#{part}"
  def live_streams_url(part \\ "snippet,cdn"),        do: @live_url <> "/liveStreams?part=#{part}"
  def chat_messages_url(chat_id, max \\ 200),         do: @live_url <> "/liveChat/messages?liveChatId=#{chat_id}&maxResults=#{max}"

  @doc "Returns OAuth2 authorization URL for user consent."
  @spec oauth_url(String.t(), String.t()) :: String.t()
  def oauth_url(redirect_uri, state \\ "") do
    params = URI.encode_query(%{
      client_id: client_id(),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: Enum.join(@scopes, " "),
      access_type: "offline",
      state: state
    })
    @auth_url <> "?" <> params
  end

  @doc "Daily quota units for common operations."
  def quota_cost(:search),          do: 100
  def quota_cost(:video_insert),    do: 1_600
  def quota_cost(:live_broadcast),  do: 50
  def quota_cost(:channels_list),   do: 1
  def quota_cost(:videos_list),     do: 1
  def quota_cost(_),                do: 1

  @doc "Daily quota limit (default 10,000 units)."
  def daily_quota_limit, do: 10_000
end
