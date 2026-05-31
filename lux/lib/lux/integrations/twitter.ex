defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Shared configuration helpers for X/Twitter API v2 integrations.

  The integration keeps credentials out of tests and supports direct overrides
  in each client call so agents can run with short-lived OAuth tokens.
  """

  @api_url "https://api.x.com"
  @authorize_url "https://x.com/i/oauth2/authorize"
  @default_scopes [
    "tweet.read",
    "tweet.write",
    "tweet.moderate.write",
    "media.write",
    "users.read",
    "follows.read",
    "follows.write",
    "offline.access"
  ]

  def api_url, do: Application.get_env(:lux, __MODULE__, [])[:api_url] || @api_url

  def authorize_url,
    do: Application.get_env(:lux, __MODULE__, [])[:authorize_url] || @authorize_url

  def default_scopes, do: @default_scopes

  def bearer_token do
    Application.get_env(:lux, :api_keys, [])
    |> Keyword.get(:twitter_bearer)
  end
end
