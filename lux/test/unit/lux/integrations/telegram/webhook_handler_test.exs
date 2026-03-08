defmodule Lux.Integrations.Telegram.WebhookHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.WebhookHandler

  describe "parse_update/1" do
    test "parses message update" do
      payload = %{
        "update_id" => 123,
        "message" => %{
          "message_id" => 456,
          "from" => %{"id" => 789, "first_name" => "Test", "username" => "testuser", "is_bot" => false},
          "chat" => %{"id" => -100, "type" => "group", "title" => "Test Group"},
          "date" => 1234567890,
          "text" => "Hello world"
        }
      }

      assert {:ok, update} = WebhookHandler.parse_update(payload)
      assert update.update_id == 123
      assert update.type == :message
      assert update.content.text == "Hello world"
      assert update.content.from.username == "testuser"
      assert update.content.chat.type == "group"
    end

    test "parses callback query" do
      payload = %{
        "update_id" => 124,
        "callback_query" => %{
          "id" => "cb1",
          "from" => %{"id" => 789, "first_name" => "Test"},
          "data" => "button_clicked",
          "chat_instance" => "inst1"
        }
      }

      assert {:ok, update} = WebhookHandler.parse_update(payload)
      assert update.type == :callback_query
      assert update.content.data == "button_clicked"
    end

    test "parses inline query" do
      payload = %{
        "update_id" => 125,
        "inline_query" => %{
          "id" => "iq1",
          "from" => %{"id" => 789, "first_name" => "Test"},
          "query" => "search term",
          "offset" => ""
        }
      }

      assert {:ok, update} = WebhookHandler.parse_update(payload)
      assert update.type == :inline_query
      assert update.content.query == "search term"
    end

    test "returns error for invalid payload" do
      assert {:error, _} = WebhookHandler.parse_update("invalid")
    end
  end

  describe "extract_command/1" do
    test "extracts command and args" do
      update = %{
        type: :message,
        content: %{text: "/start hello world"}
      }

      assert {command, args} = WebhookHandler.extract_command(update)
      assert command == "start"
      assert args == "hello world"
    end

    test "extracts command with bot mention" do
      update = %{
        type: :message,
        content: %{text: "/help@mybot some args"}
      }

      assert {"help", "some args"} = WebhookHandler.extract_command(update)
    end

    test "returns not_command for regular text" do
      update = %{
        type: :message,
        content: %{text: "just a normal message"}
      }

      assert :not_command = WebhookHandler.extract_command(update)
    end

    test "returns not_command for non-message" do
      assert :not_command = WebhookHandler.extract_command(%{type: :callback_query})
    end
  end
end
