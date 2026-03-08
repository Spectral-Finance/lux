defmodule Lux.Lenses.YouTube.GetChannelTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.GetChannel

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :api_keys, youtube_api_key: "test-key")
    :ok
  end

  test "gets channel details" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/channels"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "chan123",
            "snippet" => %{
              "title" => "My Channel",
              "description" => "Desc",
              "publishedAt" => "2026-01-01T00:00:00Z",
              "thumbnails" => %{"default" => %{"url" => "https://example.com/c.png"}}
            },
            "statistics" => %{"subscriberCount" => "1000", "videoCount" => "10", "viewCount" => "10000"},
            "contentDetails" => %{"relatedPlaylists" => %{"uploads" => "uploads123"}}
          }
        ]
      }))
    end)

    assert {:ok, channel} = GetChannel.focus(%{channel_id: "chan123", plug: {Req.Test, YouTubeClientMock}})
    assert channel.id == "chan123"
    assert channel.uploads_playlist == "uploads123"
  end
end
