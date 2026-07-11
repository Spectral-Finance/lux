defmodule Lux.Prisms.Telegram.ProcessingTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.Processing.ParseCommand
  alias Lux.Prisms.Telegram.Processing.FormatMessage
  alias Lux.Prisms.Telegram.Processing.HandleDeepLink
  alias Lux.Prisms.Telegram.Processing.ProcessCallbackQuery
  alias Lux.Prisms.Telegram.Processing.AnalyzeMessage
  alias Lux.Prisms.Telegram.Processing.ManageThread
  alias Lux.Prisms.Telegram.Processing.HandleReply

  describe "ParseCommand" do
    test "parses a simple command" do
      {:ok, result} = ParseCommand.handler(%{text: "/start"}, nil)
      assert result.is_command == true
      assert result.command == "start"
      assert result.args == []
    end

    test "parses a command with args" do
      {:ok, result} = ParseCommand.handler(%{text: "/echo hello world"}, nil)
      assert result.is_command == true
      assert result.command == "echo"
      assert result.args == ["hello", "world"]
    end

    test "parses a command directed at bot" do
      {:ok, result} = ParseCommand.handler(%{text: "/help@mybot arg", bot_username: "mybot"}, nil)
      assert result.is_command == true
      assert result.command == "help"
      assert result.args == ["arg"]
    end

    test "ignores command directed at other bot" do
      {:ok, result} = ParseCommand.handler(%{text: "/help@otherbot arg", bot_username: "mybot"}, nil)
      assert result.is_command == false
    end

    test "ignores non-commands" do
      {:ok, result} = ParseCommand.handler(%{text: "hello world"}, nil)
      assert result.is_command == false
    end
  end

  describe "FormatMessage" do
    test "escapes MarkdownV2 characters" do
      {:ok, result} = FormatMessage.handler(%{text: "Hello_World! *bold*", mode: "MarkdownV2", escape_only: true}, nil)
      assert result.formatted_text == "Hello\\_World\\! \\*bold\\*"
    end

    test "escapes HTML characters" do
      {:ok, result} = FormatMessage.handler(%{text: "<hello & world>", mode: "HTML", escape_only: true}, nil)
      assert result.formatted_text == "&lt;hello &amp; world&gt;"
    end
  end

  describe "HandleDeepLink" do
    test "extracts deep link payload" do
      {:ok, result} = HandleDeepLink.handler(%{text: "/start mypayload123"}, nil)
      assert result.is_deep_link == true
      assert result.payload == "mypayload123"
    end

    test "returns false for normal start command" do
      {:ok, result} = HandleDeepLink.handler(%{text: "/start"}, nil)
      assert result.is_deep_link == false
    end
  end

  describe "ProcessCallbackQuery" do
    test "parses action and params" do
      query = %{
        "id" => "123",
        "from" => %{"id" => 456},
        "message" => %{"message_id" => 789},
        "data" => "vote:yes:1"
      }
      {:ok, result} = ProcessCallbackQuery.handler(%{callback_query: query}, nil)
      assert result.id == "123"
      assert result.from_id == 456
      assert result.message_id == 789
      assert result.action == "vote"
      assert result.params == ["yes", "1"]
    end
  end

  describe "AnalyzeMessage" do
    test "analyzes text message" do
      message = %{"text" => "hello"}
      {:ok, result} = AnalyzeMessage.handler(%{message: message}, nil)
      assert result.content_type == "text"
      assert result.has_media == false
    end

    test "analyzes photo message" do
      message = %{
        "photo" => [%{"file_id" => "1"}, %{"file_id" => "2"}],
        "caption" => "A photo"
      }
      {:ok, result} = AnalyzeMessage.handler(%{message: message}, nil)
      assert result.content_type == "photo"
      assert result.has_media == true
      assert result.media_id == "2"
      assert result.text == "A photo"
    end
  end

  describe "ManageThread" do
    test "extracts thread id" do
      message = %{
        "is_topic_message" => true,
        "message_thread_id" => 123
      }
      {:ok, result} = ManageThread.handler(%{message: message}, nil)
      assert result.is_topic_message == true
      assert result.message_thread_id == 123
    end

    test "detects topic action" do
      message = %{"forum_topic_created" => %{}}
      {:ok, result} = ManageThread.handler(%{message: message}, nil)
      assert result.is_topic_action == true
      assert result.topic_action_type == "created"
    end
  end

  describe "HandleReply" do
    test "extracts reply info" do
      message = %{
        "reply_to_message" => %{
          "message_id" => 10,
          "from" => %{"id" => 99},
          "text" => "Original text"
        }
      }
      {:ok, result} = HandleReply.handler(%{message: message}, nil)
      assert result.is_reply == true
      assert result.replied_message_id == 10
      assert result.replied_user_id == 99
      assert result.replied_text == "Original text"
    end

    test "handles non-reply" do
      message = %{"text" => "Not a reply"}
      {:ok, result} = HandleReply.handler(%{message: message}, nil)
      assert result.is_reply == false
    end
  end
end
