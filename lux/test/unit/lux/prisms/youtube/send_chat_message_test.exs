defmodule Lux.Prisms.YouTube.SendChatMessageTest do
  @moduledoc """
  Test suite for the YouTube SendChatMessage prism.
  Verifies:
  - Successful message posting to live chat
  - Message length validation (200 char limit)
  - Error handling for ended streams
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.SendChatMessage

  @live_chat_id "EwAB_chat_id_xyz"

  setup do
    Application.put_env(:lux, :api_keys, youtube_oauth_token: "test_oauth_token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a chat message" do
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "liveChat/messages"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "LCC_newmsg",
          "snippet" => %{
            "type" => "textMessageEvent",
            "liveChatId" => @live_chat_id,
            "publishedAt" => "2024-01-15T18:10:00.000Z",
            "textMessageDetails" => %{"messageText" => "Hello viewers!"}
          },
          "authorDetails" => %{
            "displayName" => "My Channel",
            "channelId" => "UCxxx"
          }
        }))
      end)

      assert {:ok, result} = SendChatMessage.handler(%{
        "live_chat_id" => @live_chat_id,
        "message" => "Hello viewers!"
      }, %{})

      assert result.message_id == "LCC_newmsg"
      assert result.text == "Hello viewers!"
      assert result.author_name == "My Channel"
      assert result.published_at == "2024-01-15T18:10:00.000Z"
    end

    test "rejects messages exceeding 200 characters" do
      long_message = String.duplicate("A", 201)

      assert {:error, %{message: msg}} = SendChatMessage.handler(%{
        "live_chat_id" => @live_chat_id,
        "message" => long_message
      }, %{})

      assert msg =~ "200 character limit"
    end

    test "handles stream ended error" do
      Req.Test.expect(Lux.Prism, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The live chat is no longer live."}
        }))
      end)

      assert {:error, %{message: "The live chat is no longer live."}} =
               SendChatMessage.handler(%{
                 "live_chat_id" => "ended_chat",
                 "message" => "Hello?"
               }, %{})
    end
  end
end
