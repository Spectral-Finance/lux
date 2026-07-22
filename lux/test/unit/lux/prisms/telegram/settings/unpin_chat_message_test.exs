defmodule Lux.Prisms.Telegram.Settings.UnpinChatMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Settings.UnpinChatMessage

  @chat_id "123456789"
  @message_id 9876
  @agent_ctx %{name: "Agent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unpins a specific message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/unpinChatMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = UnpinChatMessage.handler(%{
        chat_id: @chat_id,
        message_id: @message_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end

    test "successfully unpins all messages" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/unpinAllChatMessages")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        refute Map.has_key?(decoded, "message_id")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, response} = UnpinChatMessage.handler(%{
        chat_id: @chat_id,
        plug: {Req.Test, __MODULE__}
      }, @agent_ctx)

      assert response.success == true
    end
  end
end
