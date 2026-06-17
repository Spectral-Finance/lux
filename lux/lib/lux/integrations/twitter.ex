defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter/X API v2 integration.

  ## Configuration

  Add your Twitter API credentials to your config:

      config :lux, :api_keys,
        twitter_bearer_token: "YOUR_BEARER_TOKEN"

  Or for OAuth 2.0 user context:

      config :lux, :api_keys,
        twitter_client_id: "YOUR_CLIENT_ID",
        twitter_client_secret: "YOUR_CLIENT_SECRET"

  ## Environment Variables

      export TWITTER_BEARER_TOKEN="YOUR_BEARER_TOKEN"

  ## Lenses (Read Operations)

  - `Lux.Lenses.Twitter.Tweets.GetTweet` - Get a single tweet by ID
  - `Lux.Lenses.Twitter.Tweets.SearchTweets` - Search recent tweets
  - `Lux.Lenses.Twitter.Tweets.GetUserTimeline` - Get a user's timeline
  - `Lux.Lenses.Twitter.Users.GetUser` - Get user profile information
  - `Lux.Lenses.Twitter.Users.GetMe` - Get authenticated user info

  ## Prisms (Write Operations)

  - `Lux.Prisms.Twitter.Tweets.CreateTweet` - Create a new tweet
  - `Lux.Prisms.Twitter.Tweets.DeleteTweet` - Delete a tweet
  - `Lux.Prisms.Twitter.Tweets.CreateThread` - Create a thread of tweets
  - `Lux.Prisms.Twitter.Tweets.QuoteTweet` - Quote tweet another tweet
  - `Lux.Prisms.Twitter.Media.UploadMedia` - Upload media for tweets
  """

  @doc """
  Common request settings for Twitter API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  @doc """
  Common headers for Twitter API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Twitter API calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Twitter Bearer token authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer_token]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer_token]
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
