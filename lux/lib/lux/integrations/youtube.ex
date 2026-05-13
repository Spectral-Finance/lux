defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Shared settings, OAuth helpers, and scopes for YouTube Data API v3.
  """

  @api_base_url "https://www.googleapis.com/youtube/v3"
  @upload_base_url "https://www.googleapis.com/upload/youtube/v3"
  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"

  @scopes %{
    readonly: "https://www.googleapis.com/auth/youtube.readonly",
    manage: "https://www.googleapis.com/auth/youtube",
    force_ssl: "https://www.googleapis.com/auth/youtube.force-ssl",
    upload: "https://www.googleapis.com/auth/youtube.upload"
  }

  @doc "Returns default YouTube API settings."
  @spec client_settings() :: map()
  def client_settings do
    %{
      api_base_url: @api_base_url,
      upload_base_url: @upload_base_url,
      headers: [{"accept", "application/json"}, {"content-type", "application/json"}]
    }
  end

  @doc "Returns OAuth endpoints used by YouTube Data API clients."
  @spec oauth_settings() :: map()
  def oauth_settings do
    %{auth_url: @auth_url, token_url: @token_url, scopes: @scopes}
  end

  @doc "Builds a Google OAuth2 authorization URL for user consent."
  @spec authorization_url(keyword() | map()) :: String.t()
  def authorization_url(opts) do
    scopes = opts |> value(:scopes, [:manage, :force_ssl, :upload]) |> normalize_scopes()

    params = %{
      client_id: value(opts, :client_id),
      redirect_uri: value(opts, :redirect_uri),
      response_type: "code",
      scope: Enum.join(scopes, " "),
      access_type: value(opts, :access_type, "offline"),
      prompt: value(opts, :prompt, "consent"),
      state: value(opts, :state)
    }

    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> URI.encode_query()

    @auth_url <> "?" <> query
  end

  @doc "Builds a token exchange request body for an authorization code."
  @spec token_request(String.t(), keyword() | map()) :: map()
  def token_request(code, opts) do
    %{
      method: :post,
      url: @token_url,
      form: %{
        code: code,
        client_id: value(opts, :client_id),
        client_secret: value(opts, :client_secret),
        redirect_uri: value(opts, :redirect_uri),
        grant_type: "authorization_code"
      }
    }
  end

  @doc "Builds a refresh-token request body."
  @spec refresh_token_request(String.t(), keyword() | map()) :: map()
  def refresh_token_request(refresh_token, opts) do
    %{
      method: :post,
      url: @token_url,
      form: %{
        refresh_token: refresh_token,
        client_id: value(opts, :client_id),
        client_secret: value(opts, :client_secret),
        grant_type: "refresh_token"
      }
    }
  end

  @doc "Returns configured scope URLs for atoms or raw scope strings."
  @spec normalize_scopes([atom() | String.t()]) :: [String.t()]
  def normalize_scopes(scopes) when is_list(scopes) do
    Enum.map(scopes, fn
      scope when is_atom(scope) -> Map.fetch!(@scopes, scope)
      scope when is_binary(scope) -> scope
    end)
  end

  defp value(map, key, default \\ nil)
  defp value(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)
end
