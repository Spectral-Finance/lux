defmodule Lux.Integration.TelegramPipelineTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.Processing.FormatConverter
  alias Lux.Prisms.Telegram.Processing.MessageThreadParser
  alias Lux.Prisms.Telegram.Processing.ReplyParser
  alias Lux.Prisms.Telegram.Processing.CallbackQueryParser
  alias Lux.Prisms.Telegram.Processing.DeepLinkParser

  describe "Telegram Processing Pipeline" do
    test "processes a complex mock Telegram update" do
      # Mock a message that represents a reply in a forum thread with a deep link
      update = %{
        "message" => %{
          "message_id" => 100,
          "from" => %{"id" => 12345, "username" => "test_user"},
          "chat" => %{"id" => -1001234567890, "type" => "supergroup", "is_forum" => true},
          "is_topic_message" => true,
          "message_thread_id" => 42,
          "text" => "/startgroup@my_bot my_payload",
          "reply_to_message" => %{
            "message_id" => 99,
            "from" => %{"id" => 98765},
            "text" => "Welcome to the topic!"
          },
          "entities" => [
            %{"type" => "bot_command", "offset" => 0, "length" => 20}
          ]
        }
      }

      # 1. Message Thread Parser
      assert {:ok, thread_res} = MessageThreadParser.handler(%{message: update["message"]}, %{})
      assert thread_res.is_topic_message == true
      assert thread_res.message_thread_id == 42
      assert thread_res.thread_state == "active"
      assert thread_res.route_to == "thread_message_handler"
      assert thread_res.planned_reply_action == %{type: "sendMessage", target_thread_id: 42}

      # 2. Reply Parser
      assert {:ok, reply_res} = ReplyParser.handler(%{message: update["message"]}, %{})
      assert reply_res.is_reply == true
      assert reply_res.replied_message_id == 99
      assert reply_res.route_to == "reply_handler"
      assert reply_res.planned_reply_action == %{type: "sendMessage", reply_to_message_id: 99}

      # 3. Deep Link Parser
      assert {:ok, dl_res} = DeepLinkParser.handler(%{text: update["message"]["text"]}, %{})
      assert dl_res.is_deep_link == true
      assert dl_res.payload == "my_payload"

      # 4. Format Converter
      format_params = %{
        text: "Response with **bold** and _italic_ and `code`",
        format: "html",
        entities: [
          %{"type" => "bold", "offset" => 14, "length" => 4},
          %{"type" => "italic", "offset" => 23, "length" => 6},
          %{"type" => "code", "offset" => 34, "length" => 4}
        ]
      }
      assert {:ok, fmt_res} = FormatConverter.handler(format_params, %{})
      assert fmt_res.formatted_text == "Response with <b>bold</b> and <i>italic</i> and <code>code</code>"
    end

    test "processes a callback query update" do
      update = %{
        "callback_query" => %{
          "id" => "cb_12345",
          "from" => %{"id" => 12345},
          "message" => %{
            "message_id" => 101,
            "chat" => %{"id" => 98765}
          },
          "data" => "action:param1=val1:flag"
        }
      }

      assert {:ok, cb_res} = CallbackQueryParser.handler(%{callback_query: update["callback_query"]}, %{})
      assert cb_res.id == "cb_12345"
      assert cb_res.action == "action"
      assert cb_res.params == %{"param1" => "val1", "flag" => true}
      assert cb_res.is_valid_payload == true
      assert cb_res.route_to == "callback_handler"
      assert cb_res.planned_actions == [%{type: "answerCallbackQuery", callback_query_id: "cb_12345"}]
    end
  end
end
