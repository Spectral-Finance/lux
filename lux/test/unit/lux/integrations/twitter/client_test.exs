defmodule Lux.Integrations.Twitter.ClientTest do
  @moduledoc """
  Test suite for the Twitter API client.
  Verifies OAuth 2.0 authentication, tweet operations, media upload,
  error handling, and rate limit management.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Client
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @bearer_token "test-bearer-token"
  @mock_api_key "mock-twitter-bearer-token"

  import Mock

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "request/3 - GET" do
    test "makes correct API call with bearer token for GET" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/users/me"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@bearer_token}"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "123456",
            "name" => "Test User",
            "username" => "testuser"
          }
        }))
      end)

      assert {:ok, %{"data" => %{"id" => "123456", "name" => "Test User"}}} =
               Client.request(:get, "/users/me", %{token: @bearer_token})
    end

    test "uses configured token when not provided" do
      api_key = @mock_api_key

      with_mock Lux.Config, [:passthrough], [twitter_bearer_token: fn -> api_key end] do
        Req.Test.expect(TwitterClientMock, fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/users/me"
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{api_key}"]

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{
            "data" => %{"id" => "789"}
          }))
        end)

        assert {:ok, %{"data" => %{"id" => "789"}}} = Client.request(:get, "/users/me")
      end
    end
  end

  describe "request/3 - POST (create tweet)" do
    test "creates a tweet successfully" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@bearer_token}"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed == %{"text" => "Hello, world!"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "987654321",
            "text" => "Hello, world!",
            "created_at" => "2026-01-15T12:00:00.000Z",
            "author_id" => "123456"
          }
        }))
      end)

      assert {:ok, %{"data" => data}} =
               Client.request(:post, "/tweets", %{
                 token: @bearer_token,
                 json: %{text: "Hello, world!"}
               })

      assert data["id"] == "987654321"
      assert data["text"] == "Hello, world!"
    end

    test "creates a tweet with reply" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["reply"]["in_reply_to_tweet_id"] == "111222"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => "333444", "text" => "Reply text"}
        }))
      end)

      assert {:ok, %{"data" => data}} =
               Client.request(:post, "/tweets", %{
                 token: @bearer_token,
                 json: %{text: "Reply text", reply: %{in_reply_to_tweet_id: "111222"}}
               })

      assert data["id"] == "333444"
    end

    test "creates a tweet with media attachment" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["media"]["media_ids"] == ["media123", "media456"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => "tweet789", "text" => "With media"}
        }))
      end)

      assert {:ok, %{"data" => data}} =
               Client.request(:post, "/tweets", %{
                 token: @bearer_token,
                 json: %{text: "With media", media: %{media_ids: ["media123", "media456"]}}
               })

      assert data["id"] == "tweet789"
    end
  end

  describe "request/3 - DELETE" do
    test "deletes a tweet successfully" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/tweets/123456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"deleted" => true}
        }))
      end)

      assert {:ok, %{"data" => %{"deleted" => true}}} =
               Client.request(:delete, "/tweets/123456", %{token: @bearer_token})
    end
  end

  describe "request/3 - error handling" do
    test "handles 401 unauthorized" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer invalid_token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "errors" => [%{"message" => "Could not authenticate with API Bearer tokens"}]
        }))
      end)

      assert {:error, {401, errors}} =
               Client.request(:get, "/users/me", %{token: "invalid_token"})

      assert is_list(errors)
    end

    test "handles 403 forbidden" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "errors" => [%{"message" => "Tweet is restricted"}]
        }))
      end)

      assert {:error, {403, errors}} =
               Client.request(:get, "/tweets/123", %{token: @bearer_token})

      assert is_list(errors)
    end

    test "handles 404 not found" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Could not find Tweet with id: 999"}]
        }))
      end)

      assert {:error, {404, errors}} =
               Client.request(:get, "/tweets/999", %{token: @bearer_token})

      assert is_list(errors)
    end

    test "handles 429 rate limiting" do
      Req.Test.expect(TwitterClientMock, 2, fn conn ->
        case conn.request_path do
          "/tweets" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(429, Jason.encode!(%{
              "title" => "Too Many Requests",
              "detail" => "Rate limit exceeded"
            }))

          _ ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{
              "data" => %{"id" => "success"}
            }))
        end
      end)

      # Should retry and eventually succeed
      assert {:error, {429, _}} =
               Client.request(:get, "/tweets", %{token: @bearer_token})
    end
  end

  describe "upload_media/3" do
    test "uploads image data successfully" do
      image_data = <<0x89, 0x50, 0x4E, 0x47>> <> "fake_png_data"

      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.starts_with?(conn.request_path, "https://upload.twitter.com")
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@bearer_token}"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "media_id_string" => "media_abc123",
          "media_key" => "3_123456",
          "size_bytes" => 4
        }))
      end)

      assert {:ok, %{"media_id_string" => "media_abc123"}} =
               Client.upload_media(image_data, "image/png", %{token: @bearer_token})
    end
  end

  describe "oauth_client_credentials/2" do
    test "obtains bearer token via OAuth 2.0" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/oauth2/token"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert length(auth_header) == 1
        assert String.starts_with?(List.first(auth_header), "Basic ")

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)
        assert params["grant_type"] == "client_credentials"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "access_token" => "new_bearer_token_123",
          "token_type" => "bearer"
        }))
      end)

      assert {:ok, "new_bearer_token_123"} =
               Client.oauth_client_credentials("api_key_123", "api_secret_456")
    end

    test "returns error on OAuth failure" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => "invalid_client",
          "error_description" => "Client authentication failed"
        }))
      end)

      assert {:error, {400, body}} =
               Client.oauth_client_credentials("bad_key", "bad_secret")

      assert body["error"] == "invalid_client"
    end
  end
end
