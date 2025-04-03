defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Client

  # Define a test module for mocking
  defmodule TwitterTestMock do
  end

  setup do
    # Ensure we verify all expected requests are made
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3" do
    test "makes correct API call with bearer token" do
      Req.Test.expect(TwitterTestMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/123456789"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "123456789",
            "text" => "This is a test tweet"
          }
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "123456789", "text" => "This is a test tweet"}}} =
               Client.request(:get, "/tweets/123456789", %{
                 plug: {Req.Test, TwitterTestMock}
               })
    end

    test "makes correct API call for POST request with JSON body" do
      Req.Test.expect(TwitterTestMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_params = Jason.decode!(body)

        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]
        assert body_params == %{"text" => "Hello, Twitter!"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => "987654321",
            "text" => "Hello, Twitter!"
          }
        }))
      end)

      assert {:ok, response} =
               Client.request(:post, "/tweets", %{
                 json: %{text: "Hello, Twitter!"},
                 plug: {Req.Test, TwitterTestMock}
               })

      assert response["data"]["id"] == "987654321"
      assert response["data"]["text"] == "Hello, Twitter!"
    end

    # Skip the token refresh test as it requires deeper mocking
    @tag :skip
    test "handles authentication error with token refresh" do
      # This test requires mocking the Twitter module which is more complex
      # and would be better implemented as an integration test
      :ok
    end

    test "handles API error with detail message" do
      Req.Test.expect(TwitterTestMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/nonexistent"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "detail" => "Tweet not found"
        }))
      end)

      assert {:error, {404, %{"detail" => "Tweet not found"}}} =
               Client.request(:get, "/tweets/nonexistent", %{
                 plug: {Req.Test, TwitterTestMock}
               })
    end

    test "handles rate limiting error" do
      Req.Test.expect(TwitterTestMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/123456789"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "detail" => "Rate limit exceeded"
        }))
      end)

      assert {:error, {429, %{"detail" => "Rate limit exceeded"}}} =
               Client.request(:get, "/tweets/123456789", %{
                 plug: {Req.Test, TwitterTestMock}
               })
    end
  end
end
