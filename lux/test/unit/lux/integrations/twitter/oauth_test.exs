defmodule Lux.Integrations.Twitter.OAuthTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.OAuth

  describe "PKCE challenge generation" do
    test "generates valid verifier and base64url challenge" do
      result = OAuth.generate_pkce_challenge()

      assert is_binary(result.code_verifier)
      assert is_binary(result.code_challenge)
      assert String.length(result.code_verifier) > 40
      assert String.length(result.code_challenge) > 20

      # Ensure challenge matches SHA-256 of verifier
      expected_challenge =
        :crypto.hash(:sha256, result.code_verifier)
        |> Base.url_encode64(padding: false)

      assert result.code_challenge == expected_challenge
    end
  end

  describe "authorization_url/5" do
    test "constructs valid OAuth 2.0 PKCE authorization url" do
      url =
        OAuth.authorization_url(
          "test_client_id_123",
          "https://myapp.com/callback",
          ["tweet.read", "tweet.write"],
          "state_abc",
          "challenge_xyz"
        )

      uri = URI.parse(url)
      assert uri.scheme == "https"
      assert uri.host == "twitter.com"
      assert uri.path == "/i/oauth2/authorize"

      query = URI.decode_query(uri.query)
      assert query["client_id"] == "test_client_id_123"
      assert query["redirect_uri"] == "https://myapp.com/callback"
      assert query["code_challenge"] == "challenge_xyz"
      assert query["code_challenge_method"] == "S256"
      assert query["state"] == "state_abc"
      assert query["response_type"] == "code"
      assert query["scope"] == "tweet.read tweet.write"
    end
  end

  describe "exchange_code/6 and refresh_token/4" do
    test "exchanges auth code for access token via mock plug" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "token_type" => "bearer",
            "expires_in" => 7200,
            "access_token" => "mock_access_token_123",
            "scope" => "tweet.read tweet.write",
            "refresh_token" => "mock_refresh_token_456"
          })
        )
      end

      {:ok, token_res} =
        OAuth.exchange_code(
          "test_client",
          "test_secret",
          "auth_code_999",
          "verifier_xyz",
          "https://myapp.com/callback",
          %{plug: plug}
        )

      assert token_res["access_token"] == "mock_access_token_123"
      assert token_res["refresh_token"] == "mock_refresh_token_456"
      assert token_res["expires_in"] == 7200
    end

    test "refreshes expired token via mock plug" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "token_type" => "bearer",
            "expires_in" => 7200,
            "access_token" => "new_access_token_789",
            "refresh_token" => "new_refresh_token_012"
          })
        )
      end

      {:ok, res} =
        OAuth.refresh_token("client_id", "client_secret", "old_refresh_token", %{plug: plug})

      assert res["access_token"] == "new_access_token_789"
      assert res["refresh_token"] == "new_refresh_token_012"
    end
  end

  describe "token encryption and decryption at rest" do
    test "encrypts and decrypts token payload with AES-256-GCM" do
      token_payload = %{
        "access_token" => "secret_access_token_xyz",
        "refresh_token" => "secret_refresh_token_abc",
        "expires_at" => 1700000000
      }

      passphrase = "lux_agent_strong_passphrase"
      encrypted = OAuth.encrypt_token(token_payload, passphrase)

      assert is_binary(encrypted)
      assert encrypted != token_payload["access_token"]

      assert {:ok, decrypted} = OAuth.decrypt_token(encrypted, passphrase)
      assert decrypted["access_token"] == "secret_access_token_xyz"
      assert decrypted["refresh_token"] == "secret_refresh_token_abc"

      # Wrong passphrase fails
      assert {:error, :decryption_failed} = OAuth.decrypt_token(encrypted, "wrong_passphrase")
    end
  end
end
