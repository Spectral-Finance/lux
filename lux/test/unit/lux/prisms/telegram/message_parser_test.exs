defmodule Lux.Prisms.Telegram.MessageParserTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.MessageParser

  test "parses text message" do
    msg = %{
      "message_id" => 123,
      "text" => "Hello world",
      "chat" => %{"id" => -100, "type" => "group"},
      "from" => %{"id" => 1, "username" => "testuser"},
      "date" => 1234567890
    }

    {:ok, result} = MessageParser.handler(%{message: msg}, nil)
    assert result.type == :text
    assert result.text == "Hello world"
    assert result.metadata.chat_id == -100
    assert result.metadata.from_username == "testuser"
  end

  test "parses photo message" do
    msg = %{"photo" => [%{"file_id" => "abc"}], "caption" => "Nice pic"}
    {:ok, result} = MessageParser.handler(%{message: msg}, nil)
    assert result.type == :photo
    assert result.text == "Nice pic"
  end

  test "parses entities" do
    msg = %{
      "text" => "/start @bot https://example.com",
      "entities" => [
        %{"type" => "bot_command", "offset" => 0, "length" => 6},
        %{"type" => "mention", "offset" => 7, "length" => 4},
        %{"type" => "url", "offset" => 12, "length" => 19}
      ]
    }

    {:ok, result} = MessageParser.handler(%{message: msg}, nil)
    assert length(result.entities) == 3
    assert Enum.at(result.entities, 0).type == "bot_command"
    assert Enum.at(result.entities, 0).value == "/start"
    assert Enum.at(result.entities, 1).value == "@bot"
  end

  test "parses reply metadata" do
    msg = %{
      "text" => "reply",
      "reply_to_message" => %{"message_id" => 99},
      "message_thread_id" => 42,
      "is_topic_message" => true
    }

    {:ok, result} = MessageParser.handler(%{message: msg}, nil)
    assert result.metadata.reply_to_message_id == 99
    assert result.metadata.message_thread_id == 42
    assert result.metadata.is_topic_message == true
  end

  test "detects all message types" do
    assert MessageParser.detect_type(%{"video" => %{}}) == :video
    assert MessageParser.detect_type(%{"document" => %{}}) == :document
    assert MessageParser.detect_type(%{"sticker" => %{}}) == :sticker
    assert MessageParser.detect_type(%{"voice" => %{}}) == :voice
    assert MessageParser.detect_type(%{"location" => %{}}) == :location
    assert MessageParser.detect_type(%{"contact" => %{}}) == :contact
    assert MessageParser.detect_type(%{"poll" => %{}}) == :poll
    assert MessageParser.detect_type(%{"animation" => %{}}) == :animation
    assert MessageParser.detect_type(%{}) == :unknown
  end

  test "handles forward metadata" do
    msg = %{
      "text" => "forwarded",
      "forward_from" => %{"id" => 555},
      "forward_from_chat" => %{"id" => -999}
    }

    {:ok, result} = MessageParser.handler(%{message: msg}, nil)
    assert result.metadata.forward_from_id == 555
    assert result.metadata.forward_from_chat_id == -999
  end
end
