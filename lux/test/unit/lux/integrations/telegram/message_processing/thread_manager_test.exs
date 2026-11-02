defmodule Lux.Integrations.Telegram.MessageProcessing.ThreadManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.ThreadManager

  describe "ThreadManager" do
    test "extracts thread information from forum supergroup message" do
      msg = %{
        "message_id" => 500,
        "chat" => %{"id" => -100_999_888, "type" => "supergroup", "is_forum" => true},
        "message_thread_id" => 42,
        "is_topic_message" => true,
        "text" => "Discussion in topic 42"
      }

      info = ThreadManager.extract_thread_info(msg)
      assert info.is_thread == true
      assert info.thread_id == 42
      assert info.is_general_topic == false
    end

    test "identifies general topic message" do
      msg = %{
        message_id: 501,
        message_thread_id: 1,
        text: "General discussion"
      }

      info = ThreadManager.extract_thread_info(msg)
      assert info.is_thread == true
      assert info.thread_id == 1
      assert info.is_general_topic == true
    end

    test "handles regular non-topic message" do
      msg = %{
        message_id: 502,
        chat: %{id: 12345, type: "private"},
        text: "Direct message"
      }

      info = ThreadManager.extract_thread_info(msg)
      assert info.is_thread == false
      assert info.thread_id == nil
    end

    test "build_thread_reply_params/2 includes message_thread_id when in thread" do
      msg = %{
        chat_id: -100_123,
        message_id: 555,
        message_thread_id: 88
      }

      params = ThreadManager.build_thread_reply_params(msg)
      assert params.chat_id == -100_123
      assert params.message_thread_id == 88
      refute Map.has_key?(params, :reply_parameters)

      quote_params = ThreadManager.build_thread_reply_params(msg, quote_reply: true)
      assert quote_params.message_thread_id == 88
      assert quote_params.reply_parameters.message_id == 555
    end

    test "extracts forum topic created event" do
      msg = %{
        message_id: 600,
        forum_topic_created: %{
          name: "Solana Alpha",
          icon_color: 7322096,
          icon_custom_emoji_id: "531234567"
        }
      }

      event = ThreadManager.extract_forum_event(msg)
      assert event.event == :created
      assert event.name == "Solana Alpha"
      assert event.icon_color == 7322096
    end
  end
end
