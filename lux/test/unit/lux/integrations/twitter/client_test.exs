defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes correct API call with bearer token" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "123",
            "username" => "test_user",
            "name" => "Test User"
          }
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "123", "username" => "test_user"}}} =
               Client.request(:get, "/users/me", %{
                 token: "test_token",
                 plug: {Req.Test, TwitterClientMock}
               })
    end

    test "makes correct POST request with JSON body" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)

        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert body_params == %{"text" => "Hello Twitter!"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => "456",
            "text" => "Hello Twitter!"
          }
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "456"}}} =
               Client.request(:post, "/tweets", %{
                 json: %{text: "Hello Twitter!"},
                 token: "test_token",
                 plug: {Req.Test, TwitterClientMock}
               })
    end

    test "handles 403 Forbidden (e.g. duplicate tweet)" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "title" => "Forbidden",
          "detail" => "Duplicate content"
        }))
      end)

      assert {:error, {:forbidden, %{"title" => "Forbidden"}}} =
               Client.request(:post, "/tweets", %{
                 token: "test_token",
                 plug: {Req.Test, TwitterClientMock}
               })
    end

    test "handles 429 Rate Limit" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "title" => "Too Many Requests"
        }))
      end)

      assert {:error, {:rate_limit, %{"title" => "Too Many Requests"}}} =
               Client.request(:get, "/users/me", %{
                 token: "test_token",
                 plug: {Req.Test, TwitterClientMock}
               })
    end
  end
end
