defmodule Lux.Integrations.YouTube.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Data API helpers" do
    test "lists authenticated user's channels with bearer token" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token-123"]

        query = URI.decode_query(conn.query_string)
        assert query["mine"] == "true"
        assert query["part"] == "id,snippet,contentDetails,statistics"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => [%{"id" => "channel-1"}]}))
      end)

      assert {:ok, %{"items" => [%{"id" => "channel-1"}]}} =
               Client.channels_mine(
                 access_token: "token-123",
                 plug: {Req.Test, YouTubeClientMock}
               )
    end

    test "starts resumable video metadata upload" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"

        query = URI.decode_query(conn.query_string)
        assert query["part"] == "snippet,status"
        assert query["uploadType"] == "resumable"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["snippet"]["title"] == "Launch recap"

        conn
        |> Plug.Conn.put_resp_header("location", "https://upload.youtube.com/session/video-1")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "video-1"}))
      end)

      assert {:ok,
              %{
                "id" => "video-1",
                "upload_url" => "https://upload.youtube.com/session/video-1"
              }} =
               Client.videos_insert(
                 %{snippet: %{title: "Launch recap"}, status: %{privacyStatus: "private"}},
                 access_token: "token-123",
                 plug: {Req.Test, YouTubeClientMock}
               )
    end
  end

  describe "Live API helpers" do
    test "transitions a broadcast" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"

        query = URI.decode_query(conn.query_string)
        assert query["id"] == "broadcast-1"
        assert query["broadcastStatus"] == "testing"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
      end)

      assert {:ok, %{"id" => "broadcast-1"}} =
               Client.live_broadcasts_transition("broadcast-1", "testing",
                 access_token: "token-123",
                 plug: {Req.Test, YouTubeClientMock}
               )
    end

    test "sends a live chat message and normalizes API errors" do
      Req.Test.expect(YouTubeClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveChat/messages"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["snippet"]["liveChatId"] == "chat-1"
        assert payload["snippet"]["textMessageDetails"]["messageText"] == "hello"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{"error" => %{"message" => "messageTextInvalid"}})
        )
      end)

      assert {:error, {400, "messageTextInvalid"}} =
               Client.live_chat_messages_insert("chat-1", "hello",
                 access_token: "token-123",
                 plug: {Req.Test, YouTubeClientMock}
               )
    end
  end
end
