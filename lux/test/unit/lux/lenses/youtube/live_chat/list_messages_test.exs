defmodule Lux.Lenses.YouTube.LiveChat.ListMessagesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.LiveChat.ListMessages

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "lists live chat messages" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/youtube/v3/liveChat/messages"
      query = URI.decode_query(conn.query_string)
      assert query["liveChatId"] == "chat-123"
      assert query["part"] == "id,snippet,authorDetails"
      assert query["maxResults"] == "25"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{
        "nextPageToken" => "next-1",
        "items" => [
          %{
            "id" => "msg-1",
            "snippet" => %{"displayMessage" => "hello", "publishedAt" => "2026-05-05T18:01:00Z"},
            "authorDetails" => %{"channelId" => "author-1", "displayName" => "Alice"}
          }
        ]
      }))
    end)

    assert {:ok, %{next_page_token: "next-1", messages: [%{id: "msg-1", message: "hello", author_name: "Alice"}]}} =
             ListMessages.focus(%{liveChatId: "chat-123", maxResults: 25})
  end
end
