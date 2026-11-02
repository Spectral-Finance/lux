defmodule Lux.YouTube.LiveStreaming.OAuthManagerTest do
  use UnitCase, async: true

  alias Lux.YouTube.LiveStreaming.OAuthManager

  describe "generate_auth_url/4" do
    test "constructs valid Google OAuth authorization URL with scopes" do
      url = OAuthManager.generate_auth_url("my_client_id", "https://app.lux/oauth/callback")

      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth?")
      assert String.contains?(url, "client_id=my_client_id")
      assert String.contains?(url, "redirect_uri=https%3A%2F%2Fapp.lux%2Foauth%2Fcallback")
      assert String.contains?(url, "scope=")
    end
  end

  describe "exchange_code_for_tokens/4 and refresh_access_token/3" do
    test "exchanges auth code for access and refresh tokens" do
      {:ok, bundle} = OAuthManager.exchange_code_for_tokens("valid_auth_code", "client", "secret", "uri")

      assert is_binary(bundle.access_token)
      assert is_binary(bundle.refresh_token)
      assert bundle.expires_at > :os.system_time(:second)
      assert OAuthManager.token_expired?(bundle) == false
    end

    test "refreshes access token successfully" do
      {:ok, refreshed} = OAuthManager.refresh_access_token("valid_refresh_token", "client", "secret")

      assert is_binary(refreshed.access_token)
      assert refreshed.refresh_token == "valid_refresh_token"
    end
  end

  describe "auth_headers/1" do
    test "returns Bearer Authorization header" do
      headers = OAuthManager.auth_headers("sample_access_token")

      assert {"Authorization", "Bearer sample_access_token"} in headers
      assert {"Content-Type", "application/json"} in headers
    end
  end
end
