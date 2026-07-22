defmodule Lux.Prisms.Telegram.Settings.PinChatMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Settings.PinChatMessage

  @chat_id "123456789"
  @message_id 9876
  @agent_ctx %{name: "Agent"}

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
        assert decoded["disable_notification"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = PinChatMessage.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        disable_notification: true,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end

    test "explicitly passes false values for disable_notification" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id
        assert decoded["disable_notification"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = PinChatMessage.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        disable_notification: false,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end
  end
end
