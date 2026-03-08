defmodule Lux.Prisms.YouTube.ManageBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.ManageBroadcast

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveBroadcasts"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "id" => "broadcast1",
        "snippet" => %{"title" => "Live"},
        "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "private"}
      }))
    end)

    assert {:ok, %{broadcast_id: "broadcast1"}} =
      ManageBroadcast.handler(%{action: "create", title: "Live", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end

  test "transitions broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveBroadcasts/transition"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"id" => "broadcast1", "status" => %{"lifeCycleStatus" => "live"}}))
    end)

    assert {:ok, %{status: "live"}} =
      ManageBroadcast.handler(%{action: "transition", broadcast_id: "broadcast1", broadcast_status: "live", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end
end
