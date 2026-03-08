defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys, youtube_api_key: "test-key")
    :ok
  end

  test "request with API key" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/search"
      assert conn.query_string =~ "key=test-key"
      assert conn.query_string =~ "q=hello"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"items" => []}))
    end)

    assert {:ok, %{"items" => []}} =
      Client.request(:get, "/search", %{params: %{q: "hello"}, plug: {Req.Test, YouTubeClientMock}})
  end

  test "request with OAuth2" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert ["Bearer token123"] = Plug.Conn.get_req_header(conn, "authorization")
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"items" => []}))
    end)

    assert {:ok, _} =
      Client.request(:get, "/channels", %{
        auth_type: :oauth2,
        access_token: "token123",
        plug: {Req.Test, YouTubeClientMock}
      })
  end

  test "refresh_access_token" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      body = Plug.Conn.read_body(conn) |> elem(1)
      assert body =~ "refresh_token"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"access_token" => "new_token"}))
    end)

    assert {:ok, "new_token"} =
      Client.refresh_access_token(%{plug: {Req.Test, YouTubeClientMock}})
  end
end
