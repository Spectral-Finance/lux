defmodule Lux.Lenses.YouTube.Videos.GetVideoTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Videos.GetVideo

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "fetches and normalizes YouTube video metadata" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/videos"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-youtube-token"]

      query = URI.decode_query(conn.query_string)
      assert query["id"] == "video-123"
      assert query["part"] == "snippet,status,contentDetails,liveStreamingDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "video-123",
            "snippet" => %{"title" => "Launch Stream", "channelId" => "channel-1"},
            "status" => %{"privacyStatus" => "public"},
            "liveStreamingDetails" => %{"activeLiveChatId" => "chat-1"}
          }
        ]
      }))
    end)

    assert {:ok, %{id: "video-123", title: "Launch Stream", channel_id: "channel-1", privacy_status: "public", active_live_chat_id: "chat-1"}} =
             GetVideo.focus(%{id: "video-123"})
  end
end
