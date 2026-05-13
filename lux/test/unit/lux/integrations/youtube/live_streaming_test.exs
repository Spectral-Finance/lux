defmodule Lux.Integrations.YouTube.LiveStreamingTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.LiveStreaming

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "live broadcast helpers" do
    test "creates a broadcast with live-streaming parts" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)

        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        assert conn.params["part"] == "snippet,status,contentDetails"
        assert body["snippet"]["title"] == "Launch stream"
        assert body["snippet"]["scheduledStartTime"] == "2026-05-13T12:00:00Z"
        assert body["status"]["privacyStatus"] == "private"
        assert body["contentDetails"]["enableAutoStop"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
      end)

      assert {:ok, %{"id" => "broadcast-1"}} =
               LiveStreaming.create_broadcast(
                 %{title: "Launch stream", scheduled_start_time: "2026-05-13T12:00:00Z"},
                 %{access_token: "access-token", plug: {Req.Test, __MODULE__}}
               )
    end

    test "transitions a broadcast to live" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
        assert conn.params["id"] == "broadcast-1"
        assert conn.params["broadcastStatus"] == "live"
        assert conn.params["part"] == "id,status"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1", "status" => %{}}))
      end)

      assert {:ok, %{"id" => "broadcast-1"}} =
               LiveStreaming.transition_broadcast("broadcast-1", "live", %{
                 access_token: "access-token",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "sends a live-chat text message" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)

        assert conn.request_path == "/youtube/v3/liveChat/messages"
        assert conn.params["part"] == "snippet"
        assert body["snippet"]["liveChatId"] == "chat-1"
        assert body["snippet"]["textMessageDetails"]["messageText"] == "hello chat"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "message-1"}))
      end)

      assert {:ok, %{"id" => "message-1"}} =
               LiveStreaming.send_chat_message("chat-1", "hello chat", %{
                 access_token: "access-token",
                 plug: {Req.Test, __MODULE__}
               })
    end
  end
end
