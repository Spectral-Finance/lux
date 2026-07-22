defmodule Lux.Prisms.Telegram.Admin.PinChatMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Admin.PinChatMessage

  @chat_id "123456789"
  @message_id 101
  @agent_ctx %{name: "AdminAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully pins a message with atom keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/pinChatMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id
        assert decoded["disable_notification"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = PinChatMessage.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        disable_notification: true
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully pins a message with string keys" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, response} = PinChatMessage.handler(%{
        "chat_id" => @chat_id,
        "message_id" => @message_id
      }, %{})

      assert response.success == true
    end

    test "handles Telegram API error response" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Message to pin not found"
        }))
      end)

      assert {:error, message} = PinChatMessage.handler(%{
        chat_id: @chat_id,
        message_id: @message_id
      }, @agent_ctx)

      assert String.contains?(message, "not found")
    end

    test "returns error on missing required params" do
      assert {:error, "Missing or invalid chat_id"} = PinChatMessage.handler(%{message_id: @message_id}, @agent_ctx)
      assert {:error, "Missing or invalid message_id"} = PinChatMessage.handler(%{chat_id: @chat_id}, @agent_ctx)
    end
  end
end
