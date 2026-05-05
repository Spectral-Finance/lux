defmodule Lux.Prisms.YouTube.LiveBroadcasts.UpdateBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.Client
  alias Lux.Prisms.YouTube.LiveBroadcasts.UpdateBroadcast

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, YouTubeClientMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "updates broadcast metadata and privacy" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"
      query = URI.decode_query(conn.query_string)
      assert query["part"] == "snippet,status,contentDetails"
      {:ok, body, _conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      assert decoded["id"] == "broadcast-1"
      assert decoded["snippet"]["title"] == "Updated"
      assert decoded["status"]["privacyStatus"] == "public"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "broadcast-1", "snippet" => %{"title" => "Updated"}, "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "public"}}))
    end)

    assert {:ok, %{id: "broadcast-1", title: "Updated", lifecycle_status: "ready", privacy_status: "public"}} =
             UpdateBroadcast.handler(%{id: "broadcast-1", title: "Updated", privacy_status: "public"}, %{name: "Agent"})
  end
end
