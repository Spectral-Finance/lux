defmodule Lux.Integrations.YouTube.OAuthTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.OAuth

  setup do
    # Start the token cache agent for testing
    {:ok, cache} = OAuth.TokenCache.start_link(%{})
    on_exit(fn ->
      if Process.alive?(cache), do: GenServer.stop(cache)
    end)
    :ok
  end

  describe "authorization_url/1" do
    test "generates correct URL with defaults" do
      url = OAuth.authorization_url()
      assert String.starts_with?(url, "https://accounts.google.com/o/oauth2/v2/auth?")
      assert url =~ "client_id="
      assert url =~ "redirect_uri="
      assert url =~ "response_type=code"
      assert url =~ "scope="
      assert url =~ "access_type=offline"
      assert url =~ "prompt=consent"
    end

    test "allows overrides" do
      url = OAuth.authorization_url(
        client_id: "custom_id",
        redirect_uri: "http://localhost/callback",
        scope: "custom_scope",
        state: "my_state"
      )
      assert url =~ "client_id=custom_id"
      assert url =~ "redirect_uri=http%3A%2F%2Flocalhost%2Fcallback"
      assert url =~ "scope=custom_scope"
      assert url =~ "state=my_state"
    end
  end

  describe "exchange_code/2" do
    test "exchanges code successfully" do
      Req.Test.stub(OAuth, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert conn.method == "POST"
        assert conn.request_path == "/token"
        assert body =~ "grant_type=authorization_code"
        assert body =~ "code=auth_code_123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "access_token" => "access_123",
          "refresh_token" => "refresh_123",
          "expires_in" => 3600
        }))
      end)

      assert {:ok, token_info} = OAuth.exchange_code("auth_code_123", plug: {Req.Test, OAuth})
      assert token_info.access_token == "access_123"
      assert token_info.refresh_token == "refresh_123"
      assert token_info.expires_in == 3600
      assert token_info.expires_at > System.system_time(:second)

      # Check cache
      assert OAuth.get_cached_token() == token_info
    end
  end

  describe "refresh_token/2" do
    test "refreshes token successfully" do
      Req.Test.stub(OAuth, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/token"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "access_token" => "access_new",
          "expires_in" => 3600
        }))
      end)

      assert {:ok, token_info} = OAuth.refresh_token("refresh_123", plug: {Req.Test, OAuth})
      assert token_info.access_token == "access_new"
      assert token_info.refresh_token == "refresh_123"
      assert token_info.expires_in == 3600
    end
  end

  describe "expired?/2" do
    test "returns true for expired or missing expiry" do
      assert OAuth.expired?(%{})
      assert OAuth.expired?(%{expires_at: System.system_time(:second) - 10})
    end

    test "returns false for valid token" do
      refute OAuth.expired?(%{expires_at: System.system_time(:second) + 120})
    end
  end
end
