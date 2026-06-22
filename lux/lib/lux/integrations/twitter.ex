defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Core configuration and entry point for Twitter/X integration.
  """

  @doc """
  Common headers for Twitter API calls.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [{"Content-Type", "application/json"}]
  end

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
    token = System.get_env("TWITTER_BEARER_TOKEN") || Application.get_env(:lux, :api_keys)[:twitter]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  def add_auth_header(%Req.Request{} = req) do
    token = System.get_env("TWITTER_BEARER_TOKEN") || Application.get_env(:lux, :api_keys)[:twitter]
    Req.Request.put_header(req, "authorization", "Bearer #{token}")
  end
end
