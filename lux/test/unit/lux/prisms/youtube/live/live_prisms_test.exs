defmodule Lux.Prisms.YouTube.Live.LivePrismsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.LiveStream
  alias Lux.Prisms.YouTube.Live.BindBroadcast
  alias Lux.Prisms.YouTube.Live.CreateBroadcast
  alias Lux.Prisms.YouTube.Live.CreateStream
  alias Lux.Prisms.YouTube.Live.SendChatMessage
  alias Lux.Prisms.YouTube.Live.TransitionBroadcast

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates a scheduled live broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"

      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet,status,contentDetails"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "title"]) == "Launch stream"
      assert get_in(decoded, ["status", "privacyStatus"]) == "unlisted"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "broadcast-1",
          "snippet" => %{"title" => "Launch stream", "liveChatId" => "chat-1"},
          "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "unlisted"},
          "contentDetails" => %{}
        })
      )
    end)

    assert {:ok, broadcast} =
             CreateBroadcast.handler(
               %{
                 title: "Launch stream",
                 scheduled_start_time: "2026-05-18T00:00:00Z",
                 privacy_status: "unlisted"
               },
               %{}
             )

    assert broadcast.id == "broadcast-1"
    assert broadcast.lifecycle_status == "ready"
    assert broadcast.live_chat_id == "chat-1"
  end

  test "creates stream ingestion settings and normalizes readiness" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveStreams"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["cdn", "resolution"]) == "1080p"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "stream-1",
          "snippet" => %{"title" => "Main stream"},
          "cdn" => %{"ingestionType" => "rtmp", "resolution" => "1080p", "frameRate" => "60fps"},
          "status" => %{"streamStatus" => "active", "healthStatus" => %{"status" => "good"}}
        })
      )
    end)

    assert {:ok, stream} = CreateStream.handler(%{title: "Main stream", frame_rate: "60fps"}, %{})
    assert stream.id == "stream-1"
    assert stream.ready_for_live == true
  end

  test "binds and transitions broadcasts" do
    Req.Test.expect(YouTubeClientMock, 2, fn conn ->
      query = URI.decode_query(conn.query_string)

      response =
        case conn.request_path do
          "/youtube/v3/liveBroadcasts/bind" ->
            assert query["id"] == "broadcast-1"
            assert query["streamId"] == "stream-1"

            %{
              "id" => "broadcast-1",
              "snippet" => %{"title" => "Launch stream"},
              "status" => %{"lifeCycleStatus" => "ready"},
              "contentDetails" => %{"boundStreamId" => "stream-1"}
            }

          "/youtube/v3/liveBroadcasts/transition" ->
            assert query["broadcastStatus"] == "testing"

            %{
              "id" => "broadcast-1",
              "snippet" => %{"title" => "Launch stream"},
              "status" => %{"lifeCycleStatus" => "testing"},
              "contentDetails" => %{"boundStreamId" => "stream-1"}
            }
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(response))
    end)

    assert {:ok, bound} =
             BindBroadcast.handler(%{broadcast_id: "broadcast-1", stream_id: "stream-1"}, %{})

    assert bound.bound_stream_id == "stream-1"

    assert {:ok, testing} =
             TransitionBroadcast.handler(
               %{broadcast_id: "broadcast-1", broadcast_status: "testing"},
               %{}
             )

    assert testing.lifecycle_status == "testing"
  end

  test "sends a live chat message" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveChat/messages"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert get_in(decoded, ["snippet", "liveChatId"]) == "chat-1"
      assert get_in(decoded, ["snippet", "textMessageDetails", "messageText"]) == "hello chat"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "msg-1",
          "snippet" => %{
            "liveChatId" => "chat-1",
            "type" => "textMessageEvent",
            "textMessageDetails" => %{"messageText" => "hello chat"}
          },
          "authorDetails" => %{"displayName" => "Lux"}
        })
      )
    end)

    assert {:ok, message} =
             SendChatMessage.handler(%{live_chat_id: "chat-1", message: "hello chat"}, %{})

    assert message.id == "msg-1"
    assert message.message == "hello chat"
  end

  test "plans safe broadcast transitions" do
    assert {:ok, ["testing", "live"]} =
             LiveStream.transition_plan(%{lifecycle_status: "ready"}, "live")

    assert {:error, _} = LiveStream.transition_plan(%{lifecycle_status: "complete"}, "live")
  end
end
