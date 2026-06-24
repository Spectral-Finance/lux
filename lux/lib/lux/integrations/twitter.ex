defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter/X API v2 integration.

  Uses OAuth 2.0 Bearer Token authentication via the `twitter_api_key`
  application config. All requests route through `https://api.twitter.com/2/`.
  """

  @base_url "https://api.twitter.com/2"

  @doc """
  Common headers for Twitter API v2 calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Twitter API v2 calls using Bearer Token.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds Twitter Bearer Token authorization header from app config.
  """
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:twitter]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @doc """
  Base URL for Twitter API v2.
  """
  def base_url, do: @base_url
end
