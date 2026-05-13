defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.Client

  @token "ya29.test-token"

  import Mock

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "authorization_url/1" do
    test "builds a consent URL with YouTube scopes and state" do
      url =
        YouTube.authorization_url(
          client_id: "client-id",
          redirect_uri: "https://example.test/oauth/youtube",
          state: "state-123"
        )

      uri = URI.parse(url)
      params = URI.decode_query(uri.query)

      assert uri.scheme == "https"
      assert uri.host == "accounts.google.com"
      assert params["client_id"] == "client-id"
      assert params["redirect_uri"] == "https://example.test/oauth/youtube"
      assert params["response_type"] == "code"
      assert params["access_type"] == "offline"
      assert params["prompt"] == "consent"
      assert params["state"] == "state-123"
      assert params["scope"] =~ "https://www.googleapis.com/auth/youtube.upload"
    end
  end

  describe "request/3" do
    test "adds bearer auth and query parameters" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"
        assert conn.query_string =~ "mine=true"
        assert conn.query_string =~ "part=snippet%2CcontentDetails%2Cstatistics"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@token}"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => [%{"id" => "channel-1"}]}))
      end)

      assert {:ok, %{"items" => [%{"id" => "channel-1"}]}} =
               Client.list_channels(%{token: @token})
    end

    test "uses configured access token when token is omitted" do
      with_mock Lux.Config, [:passthrough], youtube_access_token: fn -> @token end do
        Req.Test.expect(YouTubeClientMock, fn conn ->
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{@token}"]

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
        end)

        assert {:ok, %{"items" => []}} = Client.list_channels()
      end
    end

    test "normalizes invalid token responses" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{"error" => %{"message" => "Invalid Credentials"}})
        )
      end)

      assert {:error, :invalid_token} = Client.list_channels(%{token: "bad"})
    end

    test "normalizes rate limit responses" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          Jason.encode!(%{
            "error" => %{
              "message" => "Quota exceeded",
              "errors" => [%{"reason" => "quotaExceeded"}]
            }
          })
        )
      end)

      assert {:error, {:rate_limited, "Quota exceeded", [%{"reason" => "quotaExceeded"}]}} =
               Client.list_channels(%{token: @token})
    end
  end

  describe "token_request/2" do
    test "exchanges OAuth form data at the Google token endpoint" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/token"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = URI.decode_query(body)
        assert params["grant_type"] == "authorization_code"
        assert params["code"] == "code-123"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"access_token" => @token, "expires_in" => 3600})
        )
      end)

      assert {:ok, %{"access_token" => @token}} =
               Client.exchange_authorization_code(
                 code: "code-123",
                 client_id: "client-id",
                 client_secret: "client-secret",
                 redirect_uri: "https://example.test/oauth/youtube"
               )
    end
  end

  describe "live streaming helpers" do
    test "creates live broadcast and stream resources" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        assert conn.query_string =~ "part=snippet%2Cstatus%2CcontentDetails"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["snippet"]["title"] == "Launch"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
      end)

      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveStreams"
        assert conn.query_string =~ "part=snippet%2Ccdn%2Cstatus"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "stream-1"}))
      end)

      assert {:ok, %{"id" => "broadcast-1"}} =
               Client.insert_live_broadcast(%{snippet: %{title: "Launch"}}, %{token: @token})

      assert {:ok, %{"id" => "stream-1"}} =
               Client.insert_live_stream(%{snippet: %{title: "Primary"}}, %{token: @token})
    end

    test "binds and transitions a broadcast" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
        assert conn.query_string =~ "id=broadcast-1"
        assert conn.query_string =~ "streamId=stream-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
      end)

      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
        assert conn.query_string =~ "broadcastStatus=live"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => %{"lifeCycleStatus" => "live"}}))
      end)

      assert {:ok, %{"id" => "broadcast-1"}} =
               Client.bind_live_broadcast("broadcast-1", "stream-1", %{token: @token})

      assert {:ok, %{"status" => %{"lifeCycleStatus" => "live"}}} =
               Client.transition_live_broadcast("broadcast-1", "live", %{token: @token})
    end

    test "reads and writes live chat messages" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        assert conn.query_string =~ "liveChatId=chat-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert get_in(decoded, ["snippet", "textMessageDetails", "messageText"]) == "hello"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "message-1"}))
      end)

      assert {:ok, %{"items" => []}} = Client.list_live_chat_messages("chat-1", %{token: @token})

      assert {:ok, %{"id" => "message-1"}} =
               Client.insert_live_chat_message("chat-1", "hello", %{token: @token})
    end
  end

  describe "video uploads" do
    test "initiates a resumable upload against the upload endpoint" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert conn.query_string =~ "uploadType=resumable"
        assert conn.query_string =~ "part=snippet%2Cstatus"

        conn
        |> Plug.Conn.put_resp_header("location", "https://upload.youtube.test/session")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, %{"location" => "https://upload.youtube.test/session"}} =
               Client.initiate_resumable_upload(%{snippet: %{title: "Demo"}}, %{token: @token})
    end
  end
end
