defmodule Lux.Prisms.YouTube.OAuth.OAuthPrismsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.OAuth.ExchangeCode
  alias Lux.Prisms.YouTube.OAuth.RefreshToken

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "exchanges authorization code for tokens" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/token"
      assert Plug.Conn.get_req_header(conn, "authorization") == []

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      form = URI.decode_query(body)
      assert form["grant_type"] == "authorization_code"
      assert form["code"] == "code-123"
      assert form["redirect_uri"] == "http://localhost/callback"
      assert form["client_id"] == "test-youtube-client-id"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "access_token" => "access-123",
          "refresh_token" => "refresh-123",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        })
      )
    end)

    assert {:ok, tokens} =
             ExchangeCode.handler(
               %{code: "code-123", redirect_uri: "http://localhost/callback"},
               %{}
             )

    assert tokens.access_token == "access-123"
    assert tokens.refresh_token == "refresh-123"
  end

  test "refreshes an access token" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/token"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      form = URI.decode_query(body)
      assert form["grant_type"] == "refresh_token"
      assert form["refresh_token"] == "refresh-123"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "access_token" => "access-456",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        })
      )
    end)

    assert {:ok, tokens} = RefreshToken.handler(%{refresh_token: "refresh-123"}, %{})
    assert tokens.access_token == "access-456"
  end
end
