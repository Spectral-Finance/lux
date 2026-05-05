defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetBroadcastTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.LiveBroadcasts.GetBroadcast

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches live broadcast lifecycle state" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveBroadcasts"
      query = URI.decode_query(conn.query_string)
      assert query["id"] == "broadcast-123"
      assert query["part"] == "snippet,status,contentDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "broadcast-123",
            "snippet" => %{"title" => "Daily Alpha", "scheduledStartTime" => "2026-05-05T18:00:00Z", "liveChatId" => "chat-1"},
            "status" => %{"lifeCycleStatus" => "testing", "privacyStatus" => "unlisted"},
            "contentDetails" => %{"boundStreamId" => "stream-1"}
          }
        ]
      }))
    end)

    assert {:ok, %{id: "broadcast-123", title: "Daily Alpha", lifecycle_status: "testing", privacy_status: "unlisted", bound_stream_id: "stream-1", live_chat_id: "chat-1"}} =
             GetBroadcast.focus(%{id: "broadcast-123"})
  end
end
