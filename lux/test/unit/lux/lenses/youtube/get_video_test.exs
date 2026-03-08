defmodule Lux.Lenses.YouTube.GetVideoTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.GetVideo

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys, youtube_api_key: "test-key")
    :ok
  end

  test "gets video details" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/videos"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "vid123",
            "snippet" => %{
              "title" => "Live Stream",
              "channelId" => "chan123",
              "channelTitle" => "Channel",
              "publishedAt" => "2026-01-01T00:00:00Z"
            },
            "statistics" => %{"viewCount" => "100"},
            "contentDetails" => %{"duration" => "PT1H"},
            "liveStreamingDetails" => %{
              "activeLiveChatId" => "chat123",
              "scheduledStartTime" => "2026-01-01T01:00:00Z"
            }
          }
        ]
      }))
    end)

    assert {:ok, video} = GetVideo.focus(%{video_id: "vid123", plug: {Req.Test, YouTubeClientMock}})
    assert video.id == "vid123"
    assert video.live_broadcast == true
    assert video.live_chat_id == "chat123"
  end
end
