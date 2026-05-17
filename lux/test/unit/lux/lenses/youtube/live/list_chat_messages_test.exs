defmodule Lux.Lenses.YouTube.Live.ListChatMessagesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.Live.ListChatMessages

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists live chat messages with pagination metadata" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveChat/messages"

      query = URI.decode_query(conn.query_string)
      assert query["liveChatId"] == "chat-1"
      assert query["maxResults"] == "25"
      assert query["part"] == "snippet,authorDetails"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{
          "nextPageToken" => "next-token",
          "pollingIntervalMillis" => 2000,
          "items" => [
            %{
              "id" => "msg-1",
              "snippet" => %{
                "liveChatId" => "chat-1",
                "publishedAt" => "2026-05-18T00:01:00Z",
                "type" => "textMessageEvent",
                "textMessageDetails" => %{"messageText" => "hello"}
              },
              "authorDetails" => %{
                "channelId" => "UC-author",
                "displayName" => "Ada",
                "isChatOwner" => true
              }
            }
          ]
        })
      )
    end)

    assert {:ok, result} = ListChatMessages.focus(%{live_chat_id: "chat-1", max_results: 25})
    assert result.next_page_token == "next-token"
    assert result.polling_interval_millis == 2000

    assert [%{message: "hello", author_display_name: "Ada", author_is_chat_owner: true}] =
             result.messages
  end
end
