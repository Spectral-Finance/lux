defmodule Lux.Integrations.YouTube.LiveWorkflowTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.LiveWorkflow

  @access_token "runtime-token"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "schedules a broadcast, creates a stream, and binds them" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "id" => "broadcast-1",
          "snippet" => %{"liveChatId" => "chat-1"}
        })
      )
    end)

    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveStreams"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "stream-1"}))
    end)

    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"

      query = URI.decode_query(conn.query_string)
      assert query["id"] == "broadcast-1"
      assert query["streamId"] == "stream-1"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1"}))
    end)

    assert {:ok, %{broadcast: %{"id" => "broadcast-1"}, stream: %{"id" => "stream-1"}}} =
             LiveWorkflow.schedule(
               %{
                 access_token: @access_token,
                 title: "Launch stream",
                 scheduled_start_time: "2026-06-02T12:00:00Z",
                 plug: {Req.Test, YouTubeClientMock}
               },
               plug: {Req.Test, YouTubeClientMock}
             )
  end

  test "rejects unsafe direct live transitions" do
    assert {:error, {:unsafe_transition, "ready", "live"}} =
             LiveWorkflow.transition_broadcast("broadcast-1", "ready", "live", %{
               access_token: @access_token
             })
  end

  test "allows safe ready to testing transition" do
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
             LiveWorkflow.transition_broadcast("broadcast-1", "ready", "testing", %{
               access_token: @access_token,
               plug: {Req.Test, YouTubeClientMock}
             })
  end

  test "polls paged live chat responses" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      query = URI.decode_query(conn.query_string)
      assert query["liveChatId"] == "chat-1"
      refute Map.has_key?(query, "pageToken")

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [%{"id" => "msg-1"}],
          "nextPageToken" => "page-2",
          "pollingIntervalMillis" => 1000
        })
      )
    end)

    Req.Test.expect(YouTubeClientMock, fn conn ->
      query = URI.decode_query(conn.query_string)
      assert query["pageToken"] == "page-2"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [%{"id" => "msg-2"}]
        })
      )
    end)

    assert {:ok, %{items: [%{"id" => "msg-1"}, %{"id" => "msg-2"}]}} =
             LiveWorkflow.poll_chat_messages("chat-1", %{
               access_token: @access_token,
               max_pages: 3,
               plug: {Req.Test, YouTubeClientMock}
             })
  end
end
