defmodule Lux.Lenses.Twitter.AuthLens do
  @moduledoc """
  OAuth 2.0 PKCE token generation lens for Twitter.
  """
  use Lux.Lens,
    name: "Twitter Auth",
    description: "Fetches an OAuth 2.0 PKCE token from Twitter",
    url: "https://api.twitter.com/2/oauth2/token",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        code: %{type: :string, description: "Authorization code"},
        redirect_uri: %{type: :string, description: "Redirect URI"},
        code_verifier: %{type: :string, description: "PKCE code verifier"},
        grant_type: %{type: :string, default: "authorization_code", description: "Grant type"}
      },
      required: ["code", "redirect_uri", "code_verifier"]
    }

  @impl true
  def before_focus(params) do
    client_id = Lux.Config.twitter_client_id()
    
    Map.merge(params, %{
      client_id: client_id,
      grant_type: Map.get(params, :grant_type, "authorization_code")
    })
  end

  @impl true
  def after_focus(%{"access_token" => _} = response) do
    {:ok, %{
      access_token: response["access_token"],
      refresh_token: response["refresh_token"],
      expires_in: response["expires_in"]
    }}
  end

  def after_focus(%{"error" => error, "error_description" => desc}) do
    {:error, "#{error}: #{desc}"}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end
  
  def after_focus(_response) do
    {:error, "Unknown error"}
  end
end
