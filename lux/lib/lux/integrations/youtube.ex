defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings for YouTube Data API v3 integrations.
  """

  alias Lux.Integrations.YouTube.Client

  @doc """
  Common JSON headers for YouTube Data API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Default OAuth scopes for channel, upload, live-streaming, and chat workflows.
  """
  def scopes, do: Client.default_scopes()
end
