defmodule Lux.Prisms.Telegram.Messages.ForwardMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.ForwardMessage

  @chat_id 123_456_789
  @from_chat_id 987_654_321
  @message_id 42
  @new_message_id 123
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully forwards a message with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["from_chat_id"] == @from_chat_id
        assert decoded_body["message_id"] == @message_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @new_message_id
          }
        }))
      end)

      assert {:ok,
              %{forwarded: true, message_id: @new_message_id, from_chat_id: @from_chat_id, chat_id: @chat_id}} =
               ForwardMessage.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, TelegramClientMock}
                 },
                 @agent_ctx
               )
    end

    test "successfully forwards a message with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["from_chat_id"] == @from_chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @new_message_id
          }
        }))
      end)

      assert {:ok,
              %{forwarded: true, message_id: @new_message_id, from_chat_id: @from_chat_id, chat_id: @chat_id}} =
               ForwardMessage.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_id: @message_id,
                   disable_notification: true,
                   protect_content: true,
                   plug: {Req.Test, TelegramClientMock}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = ForwardMessage.handler(%{from_chat_id: @from_chat_id, message_id: @message_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = ForwardMessage.handler(%{chat_id: @chat_id, message_id: @message_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid from_chat_id"}

      result = ForwardMessage.handler(%{chat_id: @chat_id, from_chat_id: @from_chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid message_id"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to forward not found"
        }))
      end)

      assert {:error, "Failed to forward message: Bad Request: message to forward not found (HTTP 400)"} =
               ForwardMessage.handler(
                 %{
                   chat_id: @chat_id,
                   from_chat_id: @from_chat_id,
                   message_id: @message_id,
                   plug: {Req.Test, TelegramClientMock}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = ForwardMessage.view()
      assert prism.input_schema.required == ["chat_id", "from_chat_id", "message_id"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :from_chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
    end

    test "validates output schema" do
      prism = ForwardMessage.view()
      assert prism.output_schema.required == ["forwarded", "message_id"]
      assert Map.has_key?(prism.output_schema.properties, :forwarded)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :from_chat_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
    end
  end
end 