defmodule Lux.Prisms.Telegram.Messages.UnpinMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.UnpinMessage

  @chat_id 123_456_789
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unpins a specific message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert String.ends_with?(conn.request_path, "/unpinChatMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{unpinned: true, chat_id: @chat_id, message_id: @message_id}} =
               UnpinMessage.handler(
                 %{chat_id: @chat_id, message_id: @message_id, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "unpins the most recently pinned message when no message_id given" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        refute Map.has_key?(decoded, "message_id")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{unpinned: true, chat_id: @chat_id, message_id: nil}} =
               UnpinMessage.handler(
                 %{chat_id: @chat_id, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "handles API error for insufficient permissions" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: not enough rights to unpin a message"
        }))
      end)

      assert {:error, _reason} =
               UnpinMessage.handler(
                 %{chat_id: @chat_id, message_id: @message_id, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end
end
