defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter API v2 integration.
  """

  @doc """
  Common request settings for Twitter API v2 calls.
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
  Common headers for Twitter API v2 calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Twitter API v2 calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds Bearer token authorization header for Twitter API v2.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Lux.Config.twitter_bearer_token()
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @doc """
  Returns the Twitter API v2 base URL.
  """
  @spec base_url() :: String.t()
  def base_url, do: "https://api.twitter.com/2"

  @doc """
  Returns the Twitter Upload API base URL.
  """
  @spec upload_base_url() :: String.t()
  def upload_base_url, do: "https://upload.twitter.com/1.1"

  @doc """
  Returns the Twitter Auth API base URL for OAuth token exchange.
  """
  @spec auth_base_url() :: String.t()
  def auth_base_url, do: "https://api.twitter.com/2/oauth2"
end
