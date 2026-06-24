defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and configuration for Twitter API v2 integration.
  """

  alias Lux.Integrations.Twitter.Client
  alias Lux.Integrations.Twitter.Queue
  alias Lux.Integrations.Twitter.RuleEngine

  @doc """
  Returns the base URL for Twitter API v2.
  """
  def base_url, do: "https://api.twitter.com/2"

  @doc """
  Returns the base URL for Twitter Media API (v1.1).
  """
  def media_base_url, do: "https://upload.twitter.com/1.1"

  @doc """
  Builds standard request headers for API v2 requests using a bearer token or OAuth 2.0 access token.
  """
  def headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]
  end

  @doc """
  Builds OAuth 1.0a headers for Twitter API (required for some media endpoints if not using OAuth 2.0).
  In a real scenario, this would generate the OAuth signature.
  """
  def oauth1_headers(_method, _url, _params) do
    # Placeholder for OAuth 1.0a signature generation
    []
  end

  @doc """
  Schedules a tweet to be posted at a certain time.
  """
  def schedule_tweet(text, execute_at) do
    Queue.enqueue(text, execute_at)
  end

  @doc """
  Runs rules engine on an incoming engagement to determine next action.
  """
  def evaluate_engagement(tweet) do
    RuleEngine.evaluate(tweet)
  end

  @doc """
  Posts a tweet immediately.
  """
  def post_tweet(text) do
    Client.create_tweet(text)
  end
end
