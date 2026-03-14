defmodule Lux.Lenses.Telegram.Messages.SendMessageTest do
  @moduledoc """
  Test suite for the SendMessage lens.
  These tests verify the lens's ability to:
  - Send messages to Telegram chats
  - Handle optional parameters (parse_mode, disable_notification, etc.)
  - Handle Telegram API errors appropriately
  - Handle rate limiting (429 responses)
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.SendMessage

  @chat_id 123_456_789
  @message_id 456
  @text "Hello from Lux!"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a message with required parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == @chat_id
        assert decoded["text"] == @text

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "text" => @text,
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, %{
        message_id: @message_id,
        chat_id: @chat_id,
        text: @text,
        date: 1_234_567_890
      }} = SendMessage.focus(%{
        chat_id: @chat_id,
        text: @text
      }, %{})
    end

    test "successfully sends a message with optional parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["parse_mode"] == "MarkdownV2"
        assert decoded["disable_notification"] == true
        assert decoded["protect_content"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => @message_id,
            "chat" => %{"id" => @chat_id, "type" => "private"},
            "text" => "*Bold text*",
            "date" => 1_234_567_890
          }
        }))
      end)

      assert {:ok, %{message_id: @message_id}} = SendMessage.focus(%{
        chat_id: @chat_id,
        text: "*Bold text*",
        parse_mode: "MarkdownV2",
        disable_notification: true,
        protect_content: true
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

      assert {:error, %{reason: :api_error, error_code: 400, description: "Bad Request: chat not found"}} =
        SendMessage.focus(%{
          chat_id: @chat_id,
          text: @text
        }, %{})
    end

    test "handles rate limiting (429)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests: retry after 30",
          "parameters" => %{"retry_after" => 30}
        }))
      end)

      assert {:error, %{reason: :rate_limited, retry_after: 30}} =
        SendMessage.focus(%{
          chat_id: @chat_id,
          text: @text
        }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SendMessage.view()
      assert lens.schema.required == ["chat_id", "text"]
    end

    test "validates schema properties" do
      lens = SendMessage.view()
      assert Map.has_key?(lens.schema.properties, :chat_id)
      assert Map.has_key?(lens.schema.properties, :text)
      assert Map.has_key?(lens.schema.properties, :parse_mode)
      assert Map.has_key?(lens.schema.properties, :disable_notification)
      assert Map.has_key?(lens.schema.properties, :protect_content)
      assert Map.has_key?(lens.schema.properties, :reply_to_message_id)
      assert Map.has_key?(lens.schema.properties, :disable_web_page_preview)
    end
  end
end
