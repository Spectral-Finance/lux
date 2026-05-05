defmodule Lux.Prisms.YouTube.LiveBroadcasts.TransitionBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveBroadcasts.TransitionBroadcast

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "transitions a broadcast from testing to live" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
      query = URI.decode_query(conn.query_string)
      assert query["id"] == "broadcast-123"
      assert query["broadcastStatus"] == "live"
      assert query["part"] == "status"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-123", "status" => %{"lifeCycleStatus" => "live"}}))
    end)

    assert {:ok, %{id: "broadcast-123", lifecycle_status: "live"}} =
             TransitionBroadcast.handler(%{id: "broadcast-123", broadcast_status: "live"}, %{name: "Agent"})
  end

  test "rejects invalid broadcast statuses before calling YouTube" do
    assert {:error, "Invalid broadcast_status. Expected one of: complete, live, testing"} =
             TransitionBroadcast.handler(%{id: "broadcast-123", broadcast_status: "private"}, %{name: "Agent"})
  end
end
