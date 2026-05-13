defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Shared helpers for YouTube Data API and OAuth2 integration.
  """

  @auth_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @token_endpoint "https://oauth2.googleapis.com/token"

  @default_scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl"
  ]

  @doc """
  Builds the Google OAuth2 authorization URL for YouTube scopes.
  """
  @spec authorization_url(keyword()) :: String.t()
  def authorization_url(opts) do
    scopes = Keyword.get(opts, :scopes, @default_scopes)

    query =
      %{
        client_id: Keyword.fetch!(opts, :client_id),
        redirect_uri: Keyword.fetch!(opts, :redirect_uri),
        response_type: "code",
        scope: Enum.join(scopes, " "),
        access_type: Keyword.get(opts, :access_type, "offline"),
        prompt: Keyword.get(opts, :prompt, "consent")
      }
      |> maybe_put(:state, Keyword.get(opts, :state))
      |> URI.encode_query()

    @auth_endpoint <> "?" <> query
  end

  @doc """
  Returns the Google OAuth2 token endpoint used for code exchange and refresh.
  """
  @spec token_endpoint() :: String.t()
  def token_endpoint, do: @token_endpoint

  @doc """
  Default scopes needed for channel management, uploads, live streaming, and chat.
  """
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
