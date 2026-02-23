defmodule Lux.Lenses.YouTube.LiveChat.ListMessagesTest do
  @moduledoc """
  Test suite for the YouTube LiveChat ListMessages lens.
  Verifies:
  - Chat message retrieval with author details
  - Super chat message handling
  - Polling interval propagation
  - Empty chat handling
  - Error response propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.LiveChat.ListMessages

  @live_chat_id "EwAB_chat_id_xyz"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves chat messages" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "liveChat"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "LCC_msg1",
              "snippet" => %{
                "type" => "textMessageEvent",
                "liveChatId" => @live_chat_id,
                "publishedAt" => "2024-01-15T18:05:23.000Z",
                "textMessageDetails" => %{"messageText" => "Hello everyone!"}
              },
              "authorDetails" => %{
                "displayName" => "viewer123",
                "channelId" => "UCviewer",
                "channelUrl" => "https://www.youtube.com/channel/UCviewer",
                "profileImageUrl" => "https://example.com/avatar.jpg",
                "isChatModerator" => false,
                "isChatOwner" => false,
                "isChatSponsor" => false,
                "isVerified" => false
              }
            },
            %{
              "id" => "LCC_msg2",
              "snippet" => %{
                "type" => "superChatEvent",
                "liveChatId" => @live_chat_id,
                "publishedAt" => "2024-01-15T18:06:00.000Z",
                "superChatDetails" => %{
                  "amountDisplayString" => "$5.00",
                  "userComment" => "Great stream!",
                  "tier" => 2
                }
              },
              "authorDetails" => %{
                "displayName" => "supporter456",
                "channelId" => "UCsupporter",
                "isChatModerator" => false,
                "isChatOwner" => false,
                "isChatSponsor" => true,
                "isVerified" => false
              }
            }
          ],
          "nextPageToken" => "next_chat_token",
          "pollingIntervalMillis" => 5000
        }))
      end)

      assert {:ok, result} = ListMessages.focus(%{"live_chat_id" => @live_chat_id}, %{})

      assert length(result.messages) == 2
      assert result.next_page_token == "next_chat_token"
      assert result.polling_interval_ms == 5000

      [msg1, msg2] = result.messages

      assert msg1.id == "LCC_msg1"
      assert msg1.type == "textMessageEvent"
      assert msg1.author_name == "viewer123"
      assert msg1.text == "Hello everyone!"
      assert msg1.is_moderator == false

      assert msg2.type == "superChatEvent"
      assert msg2.is_sponsor == true
      assert msg2.text =~ "$5.00"
      assert msg2.text =~ "Great stream!"
    end

    test "handles empty chat" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "nextPageToken" => "token",
          "pollingIntervalMillis" => 10000
        }))
      end)

      assert {:ok, result} = ListMessages.focus(%{"live_chat_id" => @live_chat_id}, %{})
      assert result.messages == []
      assert result.polling_interval_ms == 10000
    end

    test "handles chat not found or broadcast ended" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The live chat is no longer live."}
        }))
      end)

      assert {:error, %{message: "The live chat is no longer live."}} =
               ListMessages.focus(%{"live_chat_id" => "ended_chat_id"}, %{})
    end
  end
end
