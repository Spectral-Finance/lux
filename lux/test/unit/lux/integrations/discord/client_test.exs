defmodule Lux.Integrations.Discord.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Discord.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes correct API call with bot token (default)" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "123456789",
          "username" => "test_bot",
          "discriminator" => "1234"
        }))
      end)

      assert {:ok, %{"id" => "123456789", "username" => "test_bot"}} =
               Client.request(:get, "/users/@me")
    end

    test "makes correct API call with bearer token" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "123456789",
          "username" => "test_user",
          "discriminator" => "1234"
        }))
      end)

      assert {:ok, %{"id" => "123456789", "username" => "test_user"}} =
               Client.request(:get, "/users/@me", %{
                 token: "test_token",
                 token_type: :bearer,
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "makes correct API call for POST request with JSON body" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)

        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/123/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]
        assert body_params == %{"content" => "Hello, Discord!"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "456",
          "content" => "Hello, Discord!",
          "channel_id" => "123"
        }))
      end)

      assert {:ok, response} =
               Client.request(:post, "/channels/123/messages", %{
                 json: %{content: "Hello, Discord!"},
                 plug: {Req.Test, __MODULE__}
               })

      assert response["id"] == "456"
      assert response["content"] == "Hello, Discord!"
    end

    test "uses configured API key when token is not provided" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "123"}))
      end)

      assert {:ok, %{"id" => "123"}} = Client.request(:get, "/users/@me", plug: {Req.Test, __MODULE__})
    end

    test "handles authentication error" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot invalid_token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"message" => "401: Unauthorized"}))
      end)

      assert {:error, :invalid_token} =
               Client.request(:get, "/users/@me", %{
                 token: "invalid_token",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "handles API error with message" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/users/@me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Too many requests"}))
      end)

      assert {:error, {429, "Too many requests"}} =
               Client.request(:get, "/users/@me", plug: {Req.Test, __MODULE__})
    end
  end
end
