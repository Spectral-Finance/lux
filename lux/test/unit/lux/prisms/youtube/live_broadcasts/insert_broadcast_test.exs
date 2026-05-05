defmodule Lux.Prisms.YouTube.LiveBroadcasts.InsertBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveBroadcasts.InsertBroadcast

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates a scheduled broadcast" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"
      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet,status,contentDetails"

      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["snippet"]["title"] == "Launch"
      assert decoded["snippet"]["scheduledStartTime"] == "2026-05-05T18:00:00Z"
      assert decoded["status"]["privacyStatus"] == "unlisted"
      assert decoded["contentDetails"]["enableAutoStart"] == true

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "id" => "broadcast-123",
        "snippet" => %{"title" => "Launch"},
        "status" => %{"lifeCycleStatus" => "created", "privacyStatus" => "unlisted"}
      }))
    end)

    assert {:ok, %{id: "broadcast-123", title: "Launch", lifecycle_status: "created"}} =
             InsertBroadcast.handler(%{
               title: "Launch",
               scheduled_start_time: "2026-05-05T18:00:00Z",
               privacy_status: "unlisted",
               enable_auto_start: true
             }, %{name: "Agent"})
  end
end
