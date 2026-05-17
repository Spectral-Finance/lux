defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and helpers for YouTube Data API integrations.
  """

  @api_endpoint "https://www.googleapis.com/youtube/v3"
  @upload_endpoint "https://www.googleapis.com/upload/youtube/v3"
  @oauth_authorization_endpoint "https://accounts.google.com/o/oauth2/v2/auth"
  @oauth_token_endpoint "https://oauth2.googleapis.com/token"

  @default_scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl"
  ]

  def api_endpoint, do: @api_endpoint
  def upload_endpoint, do: @upload_endpoint
  def oauth_token_endpoint, do: @oauth_token_endpoint
  def default_scopes, do: @default_scopes

  def headers, do: [{"Content-Type", "application/json"}]

  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Builds a YouTube OAuth2 consent URL for installed or web applications.
  """
  def oauth_authorization_url(params) do
    params = to_map(params)

    scopes =
      params
      |> get_value(:scopes, get_value(params, :scope, @default_scopes))
      |> normalize_scopes()

    client_id = get_value(params, :client_id) || Lux.Config.youtube_client_id()

    query =
      %{
        "access_type" => get_value(params, :access_type, "offline"),
        "client_id" => client_id,
        "include_granted_scopes" => get_value(params, :include_granted_scopes, true),
        "prompt" => get_value(params, :prompt, "consent"),
        "redirect_uri" => get_value(params, :redirect_uri),
        "response_type" => get_value(params, :response_type, "code"),
        "scope" => scopes,
        "state" => get_value(params, :state),
        "code_challenge" => get_value(params, :code_challenge),
        "code_challenge_method" => get_value(params, :code_challenge_method)
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    @oauth_authorization_endpoint <> "?" <> URI.encode_query(query)
  end

  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    %{
      lens
      | headers:
          lens.headers ++ [{"Authorization", "Bearer #{Lux.Config.youtube_access_token()}"}]
    }
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{Lux.Config.youtube_access_token()}")
  end

  defp normalize_scopes(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
  defp normalize_scopes(scope) when is_binary(scope), do: scope

  defp to_map(params) when is_map(params), do: params
  defp to_map(params) when is_list(params), do: Map.new(params)

  defp get_value(map, key, default \\ nil) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end
end
