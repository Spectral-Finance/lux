defmodule Lux.Prisms.YouTube.SendChatMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.SendChatMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "sends chat message" do
    Req.Test.expect(YouTubeClientMock, fn conn ->
      assert conn.request_path == "/youtube/v3/liveChat/messages"
      Plug.Conn.send_resp(conn, 200, Jason.encode!(%{
        "id" => "msg1",
        "snippet" => %{
          "textMessageDetails" => %{"messageText" => "Hello"},
          "publishedAt" => "2026-01-01T00:00:00Z"
        }
      }))
    end)

    assert {:ok, %{message_id: "msg1"}} =
      SendChatMessage.handler(%{live_chat_id: "chat1", message: "Hello", access_token: "token", plug: {Req.Test, YouTubeClientMock}}, %{})
  end
end
