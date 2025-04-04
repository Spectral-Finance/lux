defmodule Lux.Prisms.Telegram.Messages.SendMessageTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.SendMessage

  @chat_id 123_456_789
  @text "Hello from Lux!"
  @new_message_id 123
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a message with required parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["text"] == @text

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
              %{sent: true, message_id: @new_message_id, chat_id: @chat_id, text: @text}} =
               SendMessage.handler(
                 %{
                   chat_id: @chat_id,
                   text: @text,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully sends a message with optional parameters" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["text"] == @text
        assert decoded_body["parse_mode"] == "Markdown"
        assert decoded_body["disable_notification"] == true
        assert decoded_body["protect_content"] == true
        assert decoded_body["disable_web_page_preview"] == true
        assert decoded_body["reply_to_message_id"] == 42
        assert decoded_body["allow_sending_without_reply"] == true

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
              %{sent: true, message_id: @new_message_id, chat_id: @chat_id, text: @text}} =
               SendMessage.handler(
                 %{
                   chat_id: @chat_id,
                   text: @text,
                   parse_mode: "Markdown",
                   disable_notification: true,
                   protect_content: true,
                   disable_web_page_preview: true,
                   reply_to_message_id: 42,
                   allow_sending_without_reply: true,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = SendMessage.handler(%{text: @text}, @agent_ctx)
      assert result == {:error, "Missing or invalid chat_id"}

      result = SendMessage.handler(%{chat_id: @chat_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid text"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: chat not found"
        }))
      end)

      assert {:error, "Failed to send message: Bad Request: chat not found (HTTP 400)"} =
               SendMessage.handler(
                 %{
                   chat_id: @chat_id,
                   text: @text,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendMessage.view()
      assert prism.input_schema.required == ["chat_id", "text"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
      assert Map.has_key?(prism.input_schema.properties, :protect_content)
      assert Map.has_key?(prism.input_schema.properties, :disable_web_page_preview)
      assert Map.has_key?(prism.input_schema.properties, :reply_to_message_id)
      assert Map.has_key?(prism.input_schema.properties, :allow_sending_without_reply)
    end

    test "validates output schema" do
      prism = SendMessage.view()
      assert prism.output_schema.required == ["sent", "message_id", "text"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :text)
    end
  end
end
