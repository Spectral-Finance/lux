defmodule Lux.Lenses.YouTube.GetStreamHealthTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.GetStreamHealth

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "gets stream health" do
    Req.Test.stub(YouTubeClientMock, fn conn ->
      case conn.request_path do
        "/youtube/v3/liveBroadcasts" ->
          Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
            "items" => [
              %{
                "id" => "broadcast1",
                "status" => %{ "lifeCycleStatus" => "testing" },
                "contentDetails" => %{ "boundStreamId" => "stream1" }
              }
            ]
          }))

        "/youtube/v3/liveStreams" ->
          Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
            "items" => [
              %{
                "id" => "stream1",
                "cdn" => %{
                  "resolution" => "1080p",
                  "frameRate" => "30fps",
                  "ingestionType" => "rtmp",
                  "ingestionInfo" => %{ "ingestionAddress" => "rtmp://server", "streamName" => "stream-key" }
                },
                "status" => %{ "streamStatus" => "active", "healthStatus" => %{ "status" => "good" } }
              }
            ]
          }))

        _ ->
          Plug.Conn.send_resp(conn, 404, "not found")
      end
    end)

    assert {:ok, health} = GetStreamHealth.focus(%{broadcast_id: "broadcast1", access_token: "token", plug: {Req.Test, YouTubeClientMock}})
    assert health.stream_status == "active"
    assert health.health_status == "good"
    assert health.stream_name == "stream-key"
  end
end
