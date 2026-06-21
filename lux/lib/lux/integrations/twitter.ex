defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for X (Twitter) API integration.
  """

  @doc """
  Common request settings for Twitter API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :bearer,
        token: Lux.Config.twitter_bearer_token()
      }
    }
  end

  @doc """
  Common headers for Twitter API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]
end
