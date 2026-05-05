defmodule Lux.Lenses.YouTube.LiveBroadcasts.ListBroadcastsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.LiveBroadcasts.ListBroadcasts

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists broadcasts by status" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"
      query = URI.decode_query(conn.query_string)
      assert query["broadcastStatus"] == "upcoming"
      assert query["part"] == "snippet,status,contentDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "items" => [%{"id" => "broadcast-1", "snippet" => %{"title" => "Upcoming"}, "status" => %{"lifeCycleStatus" => "ready"}}]
      }))
    end)

    assert {:ok, %{broadcasts: [%{id: "broadcast-1", title: "Upcoming", lifecycle_status: "ready"}]}} =
             ListBroadcasts.focus(%{broadcast_status: "upcoming"})
  end
end
