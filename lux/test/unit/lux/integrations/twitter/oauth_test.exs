defmodule Lux.Integrations.Twitter.OAuthTest do
  use ExUnit.Case, async: true
  
  alias Lux.Integrations.Twitter.OAuth

  test "authorize_url/1 generates correct URL" do
    url = OAuth.authorize_url(%{client_id: "my_client", redirect_uri: "http://cb"})
    assert url =~ "https://twitter.com/i/oauth2/authorize"
    assert url =~ "client_id=my_client"
    assert url =~ "redirect_uri=http%3A%2F%2Fcb"
    assert url =~ "response_type=code"
    assert url =~ "code_challenge_method=plain"
  end

  test "get_token/2 makes request to twitter token endpoint" do
    Application.put_env(:lux, OAuth, plug: TwitterOAuthTestPlug)
    on_exit(fn -> Application.delete_env(:lux, OAuth) end)

    Req.Test.stub(TwitterOAuthTestPlug, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/2/oauth2/token"
      
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "grant_type=authorization_code"
      assert body =~ "code=my_code"
      
      Req.Test.json(conn, %{"access_token" => "abc", "refresh_token" => "def"})
    end)

    assert {:ok, %{"access_token" => "abc", "refresh_token" => "def"}} = OAuth.get_token("my_code")
  end

  test "refresh_token/2 makes request to twitter refresh endpoint" do
    Application.put_env(:lux, OAuth, plug: TwitterOAuthTestPlug)
    on_exit(fn -> Application.delete_env(:lux, OAuth) end)

    Req.Test.stub(TwitterOAuthTestPlug, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/2/oauth2/token"
      
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "grant_type=refresh_token"
      assert body =~ "refresh_token=my_refresh_token"
      
      Req.Test.json(conn, %{"access_token" => "new_abc", "refresh_token" => "new_def"})
    end)

    assert {:ok, %{"access_token" => "new_abc", "refresh_token" => "new_def"}} = OAuth.refresh_token("my_refresh_token")
  end
end
