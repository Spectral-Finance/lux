defmodule Lux.Lenses.Telegram.Keyboards.SendInlineKeyboardTest do
  @moduledoc """
  Test suite for the SendInlineKeyboard lens.
  These tests verify the lens's ability to:
  - Send messages with inline keyboards
  - Handle different button types (callback_data, url)
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Keyboards.SendInlineKeyboard

  @chat_id 123_456_789
  @message_id 456

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a message with inline keyboard" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["text"] == "Choose an option:"

        keyboard = decoded["reply_markup"]["inline_keyboard"]
        assert length(keyboard) == 2
        [row1, row2] = keyboard
        assert length(row1) == 2
        assert length(row2) == 1
        assert hd(row1)["callback_data"] == "opt1"
        assert hd(row2)["url"] == "https://example.com"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "text" => "Choose an option:",
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, %{
        message_id: @message_id,
        chat_id: @chat_id,
        text: "Choose an option:",
        date: 1_234_567_890
      }} = SendInlineKeyboard.focus(%{
        chat_id: @chat_id,
        text: "Choose an option:",
        reply_markup: %{
          inline_keyboard: [
            [
              %{text: "Option 1", callback_data: "opt1"},
              %{text: "Option 2", callback_data: "opt2"}
            ],
            [
              %{text: "Visit Website", url: "https://example.com"}
            ]
          ]
        }
      }, %{})
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: chat not found"
        }))
      end)

      assert {:ok, %{reason: :api_error, error_code: 400}} =
        SendInlineKeyboard.focus(%{
          chat_id: @chat_id,
          text: "Choose:",
          reply_markup: %{inline_keyboard: [[%{text: "A", callback_data: "a"}]]}
        }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 25",
          "parameters" => %{"retry_after" => 25}
        }))
      end)

      assert {:ok, %{reason: :rate_limited, retry_after: 25}} =
        SendInlineKeyboard.focus(%{
          chat_id: @chat_id,
          text: "Choose:",
          reply_markup: %{inline_keyboard: [[%{text: "A", callback_data: "a"}]]}
        }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SendInlineKeyboard.view()
      assert lens.schema.required == ["chat_id", "text", "reply_markup"]
    end

    test "validates schema properties" do
      lens = SendInlineKeyboard.view()
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :text)
      assert Map.has_key?(lens.schema.properties, :reply_markup)
      assert Map.has_key?(lens.schema.properties, :parse_mode)
      assert Map.has_key?(lens.schema.properties, :disable_notification)
    end
  end
end
