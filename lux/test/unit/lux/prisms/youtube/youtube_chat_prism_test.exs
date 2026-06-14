defmodule Lux.Prisms.YouTube.YouTubeChatPrismTest do
  use UnitCase, async: true
  alias Lux.Prisms.YouTube.YouTubeChatPrism

  @moduletag :unit

  setup do
    System.put_env("YOUTUBE_API_KEY", "test_api_key")
    :ok
  end

  test "list messages returns success with pagination" do
    Req.Test.stub(YouTubeChatPrism, fn conn ->
      Req.Test.json(conn, %{
        "items" => [%{
          "id" => "msg123",
          "snippet" => %{
            "publishedAt" => "2026-06-14T10:00:00Z",
            "textMessageDetails" => %{"messageText" => "Hello!"}
          },
          "authorDetails" => %{
            "displayName" => "TestUser",
            "channelId" => "UC123"
          }
        }],
        "nextPageToken" => "token123",
        "pollingIntervalMillis" => 5000
      })
    end)
    {:ok, result} = YouTubeChatPrism.handler(%{
      action: "list_messages",
      live_chat_id: "chat123"
    }, %{})
    assert result.status == "success"
    assert length(result.messages) == 1
    assert result.next_page_token == "token123"
  end

  test "send message returns success" do
    Req.Test.stub(YouTubeChatPrism, fn conn ->
      Req.Test.json(conn, %{
        "id" => "msg456",
        "snippet" => %{
          "publishedAt" => "2026-06-14T10:00:00Z",
          "textMessageDetails" => %{"messageText" => "Hi there!"}
        },
        "authorDetails" => %{"displayName" => "Bot", "channelId" => "UC456"}
      })
    end)
    {:ok, result} = YouTubeChatPrism.handler(%{
      action: "send_message",
      live_chat_id: "chat123",
      message: "Hi there!"
    }, %{})
    assert result.status == "success"
    assert result.message.id == "msg456"
  end

  test "delete message returns success" do
    Req.Test.stub(YouTubeChatPrism, fn conn ->
      conn |> Plug.Conn.send_resp(204, "")
    end)
    {:ok, result} = YouTubeChatPrism.handler(%{
      action: "delete_message",
      live_chat_id: "chat123",
      message_id: "msg123"
    }, %{})
    assert result.status == "success"
  end

  test "unknown action returns error" do
    result = YouTubeChatPrism.handler(%{action: "unknown", live_chat_id: "chat123"}, %{})
    assert {:error, _} = result
  end
end
