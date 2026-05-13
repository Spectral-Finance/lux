defmodule Lux.Integrations.YouTube.OAuthTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.OAuth

  describe "authorization_url/1" do
    test "builds a PKCE-enabled Google authorization URL" do
      verifier = "test-verifier"
      challenge = OAuth.pkce_challenge(verifier)

      url =
        OAuth.authorization_url(%{
          client_id: "client-id",
          redirect_uri: "https://example.com/oauth/callback",
          state: "state-123",
          code_challenge: challenge,
          scopes: ["scope-a", "scope-b"]
        })

      uri = URI.parse(url)
      params = URI.decode_query(uri.query)

      assert uri.host == "accounts.google.com"
      assert params["client_id"] == "client-id"
      assert params["redirect_uri"] == "https://example.com/oauth/callback"
      assert params["response_type"] == "code"
      assert params["access_type"] == "offline"
      assert params["scope"] == "scope-a scope-b"
      assert params["state"] == "state-123"
      assert params["code_challenge"] == challenge
      assert params["code_challenge_method"] == "S256"
    end
  end

  describe "token request bodies" do
    test "builds authorization-code exchange body" do
      assert OAuth.token_request_body("code-123", %{
               client_id: "client-id",
               redirect_uri: "https://example.com/callback",
               code_verifier: "verifier"
             }) == %{
               client_id: "client-id",
               code: "code-123",
               code_verifier: "verifier",
               grant_type: "authorization_code",
               redirect_uri: "https://example.com/callback"
             }
    end

    test "builds refresh-token body" do
      assert OAuth.refresh_request_body("refresh-token", %{
               client_id: "client-id",
               client_secret: "client-secret"
             }) == %{
               client_id: "client-id",
               client_secret: "client-secret",
               grant_type: "refresh_token",
               refresh_token: "refresh-token"
             }
    end
  end
end
