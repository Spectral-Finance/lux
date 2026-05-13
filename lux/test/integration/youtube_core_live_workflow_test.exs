defmodule Lux.Integrations.YouTubeCoreLiveWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStreaming

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates live resources, binds them, checks health, transitions, and sends chat" do
    Req.Test.expect(YouTubeWorkflowMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "broadcast-1",
          "status" => %{"lifeCycleStatus" => "ready"},
          "snippet" => %{"liveChatId" => "chat-1"}
        })
      )
    end)

    Req.Test.expect(YouTubeWorkflowMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveStreams"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "stream-1",
          "snippet" => %{"title" => "Primary Stream"},
          "cdn" => %{"resolution" => "1080p", "frameRate" => "60fps"},
          "status" => %{
            "streamStatus" => "active",
            "healthStatus" => %{"status" => "good", "configurationIssues" => []}
          }
        })
      )
    end)

    Req.Test.expect(YouTubeWorkflowMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"

      query = URI.decode_query(conn.query_string)
      assert query["id"] == "broadcast-1"
      assert query["streamId"] == "stream-1"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    Req.Test.expect(YouTubeWorkflowMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    Req.Test.expect(YouTubeWorkflowMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveChat/messages"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "msg-1"}))
    end)

    opts = [access_token: "token-123", plug: {Req.Test, YouTubeWorkflowMock}]

    assert {:ok, broadcast} =
             Client.live_broadcasts_insert(
               LiveStreaming.broadcast_body(%{
                 title: "Launch",
                 scheduled_start_time: "2026-05-13T13:00:00Z"
               }),
               opts
             )

    assert {:ok, stream} =
             Client.live_streams_insert(
               LiveStreaming.stream_body(%{title: "Primary Stream", resolution: "1080p"}),
               opts
             )

    assert {:ok, _bound} = Client.live_broadcasts_bind("broadcast-1", "stream-1", opts)
    assert {:ok, plan} = LiveStreaming.transition_plan(broadcast, stream, "testing")

    assert {:ok, _transitioned} =
             Client.live_broadcasts_transition("broadcast-1", plan.target_status, opts)

    assert {:ok, %{"id" => "msg-1"}} =
             Client.live_chat_messages_insert("chat-1", "Starting soon", opts)

    dashboard =
      LiveStreaming.dashboard(%{
        broadcast: broadcast,
        stream: stream,
        chat_messages: %{"items" => []}
      })

    assert plan.decision == :approved
    assert dashboard.health.ready_for_testing == true
    assert dashboard.quality.status == :ready
  end
end
