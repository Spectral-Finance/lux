defmodule Lux.Prisms.Telegram.Interactive.SendInlineKeyboardTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Interactive.SendInlineKeyboard

  @chat_id 123_456_789
  @text "Please choose an option:"
  @message_id 42
  @simple_keyboard [
    [
      %{text: "Option 1", callback_data: "option_1"},
      %{text: "Option 2", callback_data: "option_2"}
    ],
    [
      %{text: "Visit Website", url: "https://example.com"}
    ]
  ]
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a message with inline keyboard" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["text"] == @text

        # Verify that the reply_markup with inline_keyboard was correctly included
        assert Map.has_key?(decoded_body, "reply_markup")
        assert Map.has_key?(decoded_body["reply_markup"], "inline_keyboard")
        assert length(decoded_body["reply_markup"]["inline_keyboard"]) == 2

        # Check first row buttons
        first_row = Enum.at(decoded_body["reply_markup"]["inline_keyboard"], 0)
        assert length(first_row) == 2
        assert Enum.at(first_row, 0)["text"] == "Option 1"
        assert Enum.at(first_row, 0)["callback_data"] == "option_1"
        assert Enum.at(first_row, 1)["text"] == "Option 2"
        assert Enum.at(first_row, 1)["callback_data"] == "option_2"

        # Check second row buttons
        second_row = Enum.at(decoded_body["reply_markup"]["inline_keyboard"], 1)
        assert length(second_row) == 1
        assert Enum.at(second_row, 0)["text"] == "Visit Website"
        assert Enum.at(second_row, 0)["url"] == "https://example.com"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "text" => @text
          }
        }))
      end)

      assert {:ok, result} = SendInlineKeyboard.handler(
        %{
          chat_id: @chat_id,
          text: @text,
          inline_keyboard: @simple_keyboard,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.text == @text
    end

    test "successfully sends a message with inline keyboard and formatting" do
      formatted_text = "*Bold* text with _italics_"
      parse_mode = "Markdown"

      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)
        assert decoded_body["chat_id"] == @chat_id
        assert decoded_body["text"] == formatted_text
        assert decoded_body["parse_mode"] == parse_mode
        assert Map.has_key?(decoded_body, "reply_markup")
        assert Map.has_key?(decoded_body["reply_markup"], "inline_keyboard")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "from" => %{"id" => 987_654_321, "is_bot" => true, "first_name" => "TestBot", "username" => "test_bot"},
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "date" => 1_617_123_456,
            "text" => formatted_text,
            "entities" => [
              %{"type" => "bold", "offset" => 0, "length" => 6},
              %{"type" => "italic", "offset" => 12, "length" => 8}
            ]
          }
        }))
      end)

      assert {:ok, result} = SendInlineKeyboard.handler(
        %{
          chat_id: @chat_id,
          text: formatted_text,
          parse_mode: parse_mode,
          inline_keyboard: @simple_keyboard,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert result.sent == true
      assert result.message_id == @message_id
      assert result.chat_id == @chat_id
      assert result.text == formatted_text
    end

    test "validates required parameters" do
      # Missing chat_id
      result = SendInlineKeyboard.handler(%{
        text: @text,
        inline_keyboard: @simple_keyboard
      }, @agent_ctx)
      assert {:error, "Missing or invalid chat_id"} = result

      # Missing text
      result = SendInlineKeyboard.handler(%{
        chat_id: @chat_id,
        inline_keyboard: @simple_keyboard
      }, @agent_ctx)
      assert {:error, "Missing or invalid text"} = result

      # Missing inline_keyboard
      result = SendInlineKeyboard.handler(%{
        chat_id: @chat_id,
        text: @text
      }, @agent_ctx)
      assert {:error, "Missing or invalid inline_keyboard"} = result

      # Invalid inline_keyboard format (not a list of lists)
      result = SendInlineKeyboard.handler(%{
        chat_id: @chat_id,
        text: @text,
        inline_keyboard: [%{text: "Button", callback_data: "data"}]
      }, @agent_ctx)
      assert {:error, "Invalid inline_keyboard format: must be a list of button rows"} = result
    end

    test "handles Telegram API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "description" => "Bad Request: invalid inline keyboard button"
        }))
      end)

      assert {:error, "Failed to send message with inline keyboard: Bad Request: invalid inline keyboard button (HTTP 400)"} =
               SendInlineKeyboard.handler(
                 %{
                   chat_id: @chat_id,
                   text: @text,
                   inline_keyboard: [
                     [%{text: "Invalid Button"}] # Missing callback_data or url
                   ],
                   plug: {Req.Test, __MODULE__}
                 },
                 @agent_ctx
               )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SendInlineKeyboard.view()
      assert prism.input_schema.required == ["chat_id", "text", "inline_keyboard"]
      assert Map.has_key?(prism.input_schema.properties, :chat_id)
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert Map.has_key?(prism.input_schema.properties, :inline_keyboard)
      assert Map.has_key?(prism.input_schema.properties, :parse_mode)
      assert Map.has_key?(prism.input_schema.properties, :disable_notification)
    end

    test "validates output schema" do
      prism = SendInlineKeyboard.view()
      assert prism.output_schema.required == ["sent", "message_id", "text"]
      assert Map.has_key?(prism.output_schema.properties, :sent)
      assert Map.has_key?(prism.output_schema.properties, :message_id)
      assert Map.has_key?(prism.output_schema.properties, :chat_id)
      assert Map.has_key?(prism.output_schema.properties, :text)
    end
  end
end
