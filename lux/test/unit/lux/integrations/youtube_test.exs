defmodule Lux.Integrations.YouTubeTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube

  describe "OAuth helpers" do
    test "builds authorization URL with requested scopes" do
      url =
        YouTube.authorization_url(
          client_id: "client-123",
          redirect_uri: "https://example.com/oauth/callback",
          state: "state-123",
          scopes: [:manage, :upload]
        )

      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth?")
      assert url =~ "client_id=client-123"
      assert url =~ "response_type=code"
      assert url =~ "access_type=offline"
      assert URI.decode(url) =~ "https://www.googleapis.com/auth/youtube"
      assert URI.decode(url) =~ "https://www.googleapis.com/auth/youtube.upload"
    end

    test "builds token and refresh request payloads" do
      token_request =
        YouTube.token_request("code-123",
          client_id: "client-123",
          client_secret: "secret-123",
          redirect_uri: "https://example.com/oauth/callback"
        )

      assert token_request.method == :post
      assert token_request.form.grant_type == "authorization_code"
      assert token_request.form.code == "code-123"

      refresh_request =
        YouTube.refresh_token_request("refresh-123",
          client_id: "client-123",
          client_secret: "secret-123"
        )

      assert refresh_request.form.grant_type == "refresh_token"
      assert refresh_request.form.refresh_token == "refresh-123"
    end
  end
end
