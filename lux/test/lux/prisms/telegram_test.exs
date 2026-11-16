defmodule Lux.Prisms.TelegramTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Telegram.{Parser, CommandHandler, Formatter}

  describe "Telegram Parser" do
    test "successfully parses a standard text message" do
      update = %{
        "message" => %{
          "message_id" => 123,
          "chat" => %{"id" => 456},
          "from" => %{"id" => 789},
          "text" => "Hello Lux!",
          "date" => 1610000000
        }
      }
      result = Parser.parse(update)
      assert result.text == "Hello Lux!"
      assert result.type == :text
      assert result.chat_id == 456
    end

    test "handles callback queries" do
      update = %{
        "callback_query" => %{
          "id" => "cb1",
          "data" => "action_confirm",
          "message" => %{"message_id" => 123, "chat" => %{"id" => 456}, "date" => 1}
        }
      }
      result = Parser.parse(update)
      assert result.type == :callback_query
      assert result.data == "action_confirm"
    end
  end

  describe "Command Handler" do
    test "extracts commands and arguments" do
      assert {:ok, "start", ["123"]} = CommandHandler.parse_command("/start 123")
      assert {:ok, "help", []} = CommandHandler.parse_command("/help")
      assert :error = CommandHandler.parse_command("not a command")
    end

    test "extracts deep links" do
      assert {:ok, "ref_code"} = CommandHandler.extract_deep_link("/start ref_code")
    end
  end

  describe "Formatter" do
    test "escapes MarkdownV2 special characters" do
      input = "Hello! [World] (v1.0)"
      # Note: In Elixir strings, backslashes need to be escaped
      expected = "Hello\\! \\[World\\] \\(v1\\.0\\)"
      assert Formatter.escape_markdown_v2(input) == expected
    end
  end
end
