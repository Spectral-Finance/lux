defmodule Lux.Prisms.YouTube.YouTubeAuthPrism do
  @moduledoc """
  A prism for YouTube OAuth2 authentication - get token, refresh token.
  """

  use Lux.Prism,
    name: "YouTube Auth",
    description: "Handles YouTube OAuth2 token exchange and refresh",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["get_auth_url", "exchange_code", "refresh_token"]},
        code: %{type: :string, description: "Authorization code from OAuth callback"},
        refresh_token: %{type: :string, description: "Refresh token"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        auth_url: %{type: :string},
        access_token: %{type: :string},
        refresh_token: %{type: :string},
        expires_in: %{type: :integer}
      },
      required: ["status"]
    }

  @oauth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @scopes "https://www.googleapis.com/auth/youtube https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.force-ssl"

  def handler(input, _ctx) do
    case input.action do
      "get_auth_url"    -> get_auth_url()
      "exchange_code"   -> exchange_code(input.code)
      "refresh_token"   -> refresh_token(input.refresh_token)
      _                 -> {:error, "Unknown action: #{input.action}"}
    end
  end

  defp get_auth_url do
    client_id = Lux.Config.get(:youtube_client_id) || System.get_env("YOUTUBE_CLIENT_ID")
    redirect_uri = Lux.Config.get(:youtube_redirect_uri) || System.get_env("YOUTUBE_REDIRECT_URI") || "http://localhost:4000/callback"
    params = URI.encode_query(%{
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: @scopes,
      access_type: "offline",
      prompt: "consent"
    })
    {:ok, %{status: "success", auth_url: "#{@oauth_url}?#{params}"}}
  end

  defp exchange_code(code) do
    client_id     = Lux.Config.get(:youtube_client_id) || System.get_env("YOUTUBE_CLIENT_ID")
    client_secret = Lux.Config.get(:youtube_client_secret) || System.get_env("YOUTUBE_CLIENT_SECRET")
    redirect_uri  = Lux.Config.get(:youtube_redirect_uri) || System.get_env("YOUTUBE_REDIRECT_URI") || "http://localhost:4000/callback"

    case Req.post(@token_url, form: %{
      code: code,
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    }) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          status: "success",
          access_token: body["access_token"],
          refresh_token: body["refresh_token"],
          expires_in: body["expires_in"],
          token_type: body["token_type"]
        }}
      {:ok, %{status: s, body: b}} -> {:error, "OAuth error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp refresh_token(refresh_token) do
    client_id     = Lux.Config.get(:youtube_client_id) || System.get_env("YOUTUBE_CLIENT_ID")
    client_secret = Lux.Config.get(:youtube_client_secret) || System.get_env("YOUTUBE_CLIENT_SECRET")

    case Req.post(@token_url, form: %{
      refresh_token: refresh_token,
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "refresh_token"
    }) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{
          status: "success",
          access_token: body["access_token"],
          expires_in: body["expires_in"]
        }}
      {:ok, %{status: s, body: b}} -> {:error, "OAuth error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end
end
