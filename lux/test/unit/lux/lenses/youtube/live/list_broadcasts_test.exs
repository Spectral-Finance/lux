defmodule Lux.Lenses.YouTube.Live.ListBroadcastsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Live.ListBroadcasts

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists broadcasts with lifecycle data" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"

      query = URI.decode_query(conn.query_string)
      assert query["broadcastStatus"] == "upcoming"
      assert query["mine"] == "true"
      assert query["part"] == "snippet,status,contentDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "items" => [
            %{
              "id" => "broadcast-1",
              "snippet" => %{
                "title" => "Launch stream",
                "scheduledStartTime" => "2026-05-18T00:00:00Z",
                "liveChatId" => "chat-1"
              },
              "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "unlisted"},
              "contentDetails" => %{"boundStreamId" => "stream-1"}
            }
          ]
        })
      )
    end)

    assert {:ok, [broadcast]} = ListBroadcasts.focus(%{broadcast_status: "upcoming"})
    assert broadcast.id == "broadcast-1"
    assert broadcast.lifecycle_status == "ready"
    assert broadcast.live_chat_id == "chat-1"
    assert broadcast.bound_stream_id == "stream-1"
  end
end
