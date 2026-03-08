defmodule Lux.Lenses.YouTube.GetLiveChatTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.GetLiveChat

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "gets live chat messages" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveChat/messages"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "items" => [
          %{
            "id" => "msg1",
            "snippet" => %{
              "displayMessage" => "Hello",
              "publishedAt" => "2026-01-01T00:00:00Z"
            },
            "authorDetails" => %{
              "displayName" => "User1",
              "channelId" => "chan1",
              "isChatModerator" => true,
              "isChatOwner" => false
            }
          }
        ],
        "nextPageToken" => "next",
        "pollingIntervalMillis" => 5000
      }))
    end)

    assert {:ok, %{messages: [msg], next_page_token: "next"}} =
      GetLiveChat.focus(%{live_chat_id: "chat1", access_token: "token", plug: {Req.Test, YouTubeClientMock}})
    assert msg.message == "Hello"
    assert msg.author_name == "User1"
  end
end
