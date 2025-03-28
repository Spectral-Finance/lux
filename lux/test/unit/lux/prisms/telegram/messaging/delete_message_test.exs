defmodule Lux.Prisms.Telegram.Messages.DeleteMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.DeleteMessage

  @chat_id 123_456_789
  @message_id 42
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a message" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok,
              %{deleted: true, message_id: @message_id, chat_id: @chat_id}} =
               DeleteMessage.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, TelegramClientMock}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = DeleteMessage.handler(%{message_id: @message_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = DeleteMessage.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid message_id"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to delete not found"
        }))
      end)

      assert {:error, "Failed to delete message: Bad Request: message to delete not found (HTTP 400)"} =
               DeleteMessage.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, TelegramClientMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = DeleteMessage.view()
      assert prism.input_schema.required == ["chat_id", "message_id"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
    end

    test "validates output schema" do
      prism = DeleteMessage.view()
      assert prism.output_schema.required == ["deleted"]
      assert Map.has_key?(prism.output_schema.properties, :deleted)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end 