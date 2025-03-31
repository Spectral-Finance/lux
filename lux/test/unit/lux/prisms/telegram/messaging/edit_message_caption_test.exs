defmodule Lux.Prisms.Telegram.Messages.EditMessageCaptionTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Messages.EditMessageCaption

  @chat_id 123_456_789
  @message_id 42
  @inline_message_id "CAAqrxJRAqABAZaiqJ4sAJtvlCQI"
  @caption "Updated caption"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a message caption with chat_id and message_id" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["caption"] == @caption

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "caption" => @caption
          }
        }))
      end)

      assert {:ok,
              %{edited: true, message_id: @message_id, chat_id: @chat_id, caption: @caption}} =
               EditMessageCaption.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully edits an inline message caption" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["inline_message_id"] == @inline_message_id
        assert decoded_body["caption"] == @caption

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, %{edited: true}} =
               EditMessageCaption.handler(
                 %{
                   inline_message_id: @inline_message_id,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "successfully edits a message caption with parse_mode" do
      parse_mode = "Markdown"
      formatted_caption = "*Bold* caption"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["message_id"] == @message_id
        assert decoded_body["caption"] == formatted_caption
        assert decoded_body["parse_mode"] == parse_mode

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "edit_date" => 1_617_123_459,
            "caption" => formatted_caption
          }
        }))
      end)

      assert {:ok, %{edited: true, caption: ^formatted_caption}} =
               EditMessageCaption.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   caption: formatted_caption,
                   parse_mode: parse_mode,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end

    test "validates required parameters" do
      result = EditMessageCaption.handler(%{message_id: @message_id}, @agent_ctx)
      assert result == {:error, "Missing or invalid caption"}

      result = EditMessageCaption.handler(%{caption: @caption}, @agent_ctx)
      assert result == {:error, "Missing or invalid message identifier: Either (chat_id and message_id) or inline_message_id must be provided"}
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: message to edit not found"
        }))
      end)

      assert {:error, "Failed to edit message caption: Bad Request: message to edit not found (HTTP 400)"} =
               EditMessageCaption.handler(
                 %{
                   chat_id: @chat_id,
                   message_id: @message_id,
                   caption: @caption,
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EditMessageCaption.view()
      assert prism.input_schema.required == ["caption"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :message_id)
      assert Map.has_key?(prism.input_schema.properties, :inline_message_id)
      assert Map.has_key?(prism.input_schema.properties, :caption)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
    end

    test "validates output schema" do
      prism = EditMessageCaption.view()
      assert prism.output_schema.required == ["edited"]
      assert Map.has_key?(prism.output_schema.properties, :edited)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :caption)
    end
  end
end
