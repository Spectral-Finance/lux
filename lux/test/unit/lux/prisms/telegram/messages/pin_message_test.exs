defmodule Lux.Prisms.Telegram.Messages.PinMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.PinMessage

  @chat_id 123_456_789
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully pins a message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/pinChatMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{pinned: true, chat_id: @chat_id, message_id: @message_id}} =
               PinMessage.handler(
                 %{chat_id: @chat_id, message_id: @message_id, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "pins a message with disable_notification" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["disable_notification"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{pinned: true}} =
               PinMessage.handler(
                 %{chat_id: @chat_id, message_id: @message_id, disable_notification: true, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: not enough rights to pin a message"
        }))
      end)

      assert {:error, _reason} =
               PinMessage.handler(
                 %{chat_id: @chat_id, message_id: @message_id, plug: {Req.Test, __MODULE__}},
                 @agent_ctx
               )
    end
  end
end
