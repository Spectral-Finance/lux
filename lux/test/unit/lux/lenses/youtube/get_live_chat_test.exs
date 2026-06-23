defmodule Lux.Lenses.YouTube.GetLiveChatTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.GetLiveChat

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "GetLiveChat focus" do
    test "successfully retrieves live chat messages and pagination details" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveChat/messages"
        assert conn.params["liveChatId"] == "chat_123"
        assert conn.params["pageToken"] == "token_abc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "msg_1",
              "snippet" => %{
                "type" => "textMessageEvent",
                "publishedAt" => "2024-01-01T20:00:00Z",
                "textMessageDetails" => %{"messageText" => "Hello chat!"}
              },
              "authorDetails" => %{
                "channelId" => "author_channel_1",
                "displayName" => "User One",
                "profileImageUrl" => "http://profile/1.jpg",
                "isChatOwner" => false
              }
            }
          ],
          "nextPageToken" => "token_next",
          "pollingIntervalMillis" => 6000
        }))
      end)

      assert {:ok, result} = GetLiveChat.focus(%{
        live_chat_id: "chat_123",
        page_token: "token_abc"
      }, %{})

      assert result.next_page_token == "token_next"
      assert result.polling_interval_millis == 6000
      assert [message] = result.messages
      assert message.id == "msg_1"
      assert message.text == "Hello chat!"
      assert message.display_name == "User One"
    end
  end
end
